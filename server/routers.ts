import { COOKIE_NAME } from "@shared/const";
import { getSessionCookieOptions } from "./_core/cookies";
import { systemRouter } from "./_core/systemRouter";
import { publicProcedure, router, protectedProcedure } from "./_core/trpc";
import { z } from "zod";
import { TRPCError } from "@trpc/server";
import { getDb } from "./db";
import { categories, content, users } from "../drizzle/schema";
import { eq, and } from "drizzle-orm";
import { getCategories, getContentByCategory, getContentById } from "./db";
import { S3Client, PutObjectCommand, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";

// ============================================
// INITIALIZE R2 CLIENT
// ============================================

const s3Client = new S3Client({
  region: "auto",
  endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
  credentials: {
    accessKeyId: process.env.R2_ACCESS_KEY_ID || "",
    secretAccessKey: process.env.R2_SECRET_ACCESS_KEY || "",
  },
});

// ============================================
// HELPER PROCEDURES
// ============================================

/**
 * Admin-only procedure that checks if user has admin role
 */
const adminProcedure = protectedProcedure.use(async ({ ctx, next }) => {
  if (!ctx.user) {
    throw new TRPCError({ code: "UNAUTHORIZED" });
  }

  const db = await getDb();
  if (!db) {
    throw new TRPCError({
      code: "INTERNAL_SERVER_ERROR",
      message: "Database not available",
    });
  }

  try {
    const userRecord = await db
      .select()
      .from(users)
      .where(eq(users.id, ctx.user.id))
      .limit(1);

    if (userRecord.length === 0 || userRecord[0].role !== "admin") {
      throw new TRPCError({
        code: "FORBIDDEN",
        message: "Admin access required",
      });
    }

    return next({ ctx });
  } catch (error) {
    if (error instanceof TRPCError) throw error;
    throw new TRPCError({
      code: "INTERNAL_SERVER_ERROR",
      message: "Failed to verify admin status",
    });
  }
});

// ============================================
// ROUTERS
// ============================================

export const appRouter = router({
  system: systemRouter,

  // ============================================
  // AUTHENTICATION ROUTES
  // ============================================
  auth: router({
    me: publicProcedure.query((opts) => opts.ctx.user),
    logout: publicProcedure.mutation(({ ctx }) => {
      const cookieOptions = getSessionCookieOptions(ctx.req);
      ctx.res.clearCookie(COOKIE_NAME, { ...cookieOptions, maxAge: -1 });
      return {
        success: true,
      } as const;
    }),
  }),

  // ============================================
  // HEALTH CHECK
  // ============================================
  health: router({
    check: publicProcedure.query(() => ({
      status: "ok",
      timestamp: new Date().toISOString(),
      service: "Content Management Backend",
    })),
  }),

  // ============================================
  // CATEGORY ROUTES
  // ============================================
  categories: router({
    /**
     * Get all active categories
     */
    list: publicProcedure.query(async () => {
      try {
        const result = await getCategories();
        return result;
      } catch (error) {
        console.error("[Categories] List error:", error);
        throw new TRPCError({
          code: "INTERNAL_SERVER_ERROR",
          message: "Failed to fetch categories",
        });
      }
    }),

    /**
     * Create new category (admin only)
     */
    create: adminProcedure
      .input(
        z.object({
          name: z.string().min(1, "Category name required"),
          description: z.string().optional(),
          icon: z.string().optional(),
          displayOrder: z.number().optional().default(0),
        })
      )
      .mutation(async ({ input }) => {
        try {
          const db = await getDb();
          if (!db) {
            throw new TRPCError({
              code: "INTERNAL_SERVER_ERROR",
              message: "Database not available",
            });
          }

          const result = await db
            .insert(categories)
            .values({
              name: input.name,
              description: input.description,
              icon: input.icon,
              displayOrder: input.displayOrder,
              isActive: true,
            })
            .$returningId();

          console.log("[Categories] Created:", input.name);
          return { success: true, id: result[0].id };
        } catch (error) {
          console.error("[Categories] Create error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to create category",
          });
        }
      }),

    /**
     * Update category (admin only)
     */
    update: adminProcedure
      .input(
        z.object({
          id: z.number(),
          name: z.string().optional(),
          description: z.string().optional(),
          icon: z.string().optional(),
          displayOrder: z.number().optional(),
        })
      )
      .mutation(async ({ input }) => {
        try {
          const db = await getDb();
          if (!db) {
            throw new TRPCError({
              code: "INTERNAL_SERVER_ERROR",
              message: "Database not available",
            });
          }

          const updateData: any = {
            updatedAt: new Date(),
          };

          if (input.name !== undefined) updateData.name = input.name;
          if (input.description !== undefined)
            updateData.description = input.description;
          if (input.icon !== undefined) updateData.icon = input.icon;
          if (input.displayOrder !== undefined)
            updateData.displayOrder = input.displayOrder;

          await db
            .update(categories)
            .set(updateData)
            .where(eq(categories.id, input.id));

          console.log("[Categories] Updated:", input.id);
          return { success: true };
        } catch (error) {
          console.error("[Categories] Update error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to update category",
          });
        }
      }),

    /**
     * Delete category (admin only)
     */
    delete: adminProcedure
      .input(z.object({ id: z.number() }))
      .mutation(async ({ input }) => {
        try {
          const db = await getDb();
          if (!db) {
            throw new TRPCError({
              code: "INTERNAL_SERVER_ERROR",
              message: "Database not available",
            });
          }

          await db.delete(categories).where(eq(categories.id, input.id));

          console.log("[Categories] Deleted:", input.id);
          return { success: true };
        } catch (error) {
          console.error("[Categories] Delete error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to delete category",
          });
        }
      }),
  }),

  // ============================================
  // CONTENT ROUTES
  // ============================================
  content: router({
    /**
     * Get content by category
     */
    byCategory: publicProcedure
      .input(z.object({ categoryId: z.number() }))
      .query(async ({ input }) => {
        try {
          const result = await getContentByCategory(input.categoryId);
          return result;
        } catch (error) {
          console.error("[Content] Get by category error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to fetch content",
          });
        }
      }),

    /**
     * Get single content item
     */
    getById: publicProcedure
      .input(z.object({ id: z.number() }))
      .query(async ({ input }) => {
        try {
          const result = await getContentById(input.id);
          if (!result) {
            throw new TRPCError({
              code: "NOT_FOUND",
              message: "Content not found",
            });
          }
          return result;
        } catch (error) {
          if (error instanceof TRPCError) throw error;
          console.error("[Content] Get by ID error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to fetch content",
          });
        }
      }),

    /**
     * Create new content (admin only)
     */
    create: adminProcedure
      .input(
        z.object({
          categoryId: z.number(),
          title: z.string().min(1, "Title required"),
          description: z.string().optional(),
          contentType: z.enum(["folder", "link", "image", "text"]),
          accessLevel: z.enum(["free", "paid"]).default("free"),
          r2FileKey: z.string().optional(),
          r2Url: z.string().optional(),
          fileSize: z.number().optional(),
          mimeType: z.string().optional(),
          externalUrl: z.string().optional(),
          textContent: z.string().optional(),
        })
      )
      .mutation(async ({ input, ctx }) => {
        try {
          const db = await getDb();
          if (!db) {
            throw new TRPCError({
              code: "INTERNAL_SERVER_ERROR",
              message: "Database not available",
            });
          }

          const result = await db
            .insert(content)
            .values({
              categoryId: input.categoryId,
              title: input.title,
              description: input.description,
              contentType: input.contentType,
              accessLevel: input.accessLevel,
              r2FileKey: input.r2FileKey,
              r2Url: input.r2Url,
              fileSize: input.fileSize,
              mimeType: input.mimeType,
              externalUrl: input.externalUrl,
              textContent: input.textContent,
              uploadedBy: ctx.user?.id,
              isActive: true,
            })
            .$returningId();

          console.log("[Content] Created:", input.title);
          return { success: true, id: result[0].id };
        } catch (error) {
          console.error("[Content] Create error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to create content",
          });
        }
      }),

    /**
     * Update content (admin only)
     */
    update: adminProcedure
      .input(
        z.object({
          id: z.number(),
          title: z.string().optional(),
          description: z.string().optional(),
          accessLevel: z.enum(["free", "paid"]).optional(),
          isActive: z.boolean().optional(),
        })
      )
      .mutation(async ({ input }) => {
        try {
          const db = await getDb();
          if (!db) {
            throw new TRPCError({
              code: "INTERNAL_SERVER_ERROR",
              message: "Database not available",
            });
          }

          const updateData: any = {
            updatedAt: new Date(),
          };

          if (input.title !== undefined) updateData.title = input.title;
          if (input.description !== undefined)
            updateData.description = input.description;
          if (input.accessLevel !== undefined)
            updateData.accessLevel = input.accessLevel;
          if (input.isActive !== undefined) updateData.isActive = input.isActive;

          await db
            .update(content)
            .set(updateData)
            .where(eq(content.id, input.id));

          console.log("[Content] Updated:", input.id);
          return { success: true };
        } catch (error) {
          console.error("[Content] Update error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to update content",
          });
        }
      }),

    /**
     * Delete content (admin only)
     */
    delete: adminProcedure
      .input(z.object({ id: z.number() }))
      .mutation(async ({ input }) => {
        try {
          const db = await getDb();
          if (!db) {
            throw new TRPCError({
              code: "INTERNAL_SERVER_ERROR",
              message: "Database not available",
            });
          }

          await db.delete(content).where(eq(content.id, input.id));

          console.log("[Content] Deleted:", input.id);
          return { success: true };
        } catch (error) {
          console.error("[Content] Delete error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to delete content",
          });
        }
      }),
  }),

  // ============================================
  // R2 FILE STORAGE ROUTES
  // ============================================
  r2: router({
    /**
     * Generate presigned URL for file upload (admin only)
     */
    getUploadUrl: adminProcedure
      .input(
        z.object({
          fileName: z.string().min(1),
          contentType: z.string().min(1),
          fileSize: z.number().optional(),
        })
      )
      .mutation(async ({ input }) => {
        try {
          // Validate file size (max 500MB)
          if (input.fileSize && input.fileSize > 500 * 1024 * 1024) {
            throw new TRPCError({
              code: "BAD_REQUEST",
              message: "File size exceeds 500MB limit",
            });
          }

          // Generate unique file key
          const timestamp = Date.now();
          const sanitized = input.fileName.replace(/[^a-zA-Z0-9.-]/g, "_");
          const fileKey = `uploads/${timestamp}-${sanitized}`;

          // Generate presigned URL
          const presignedUrl = await getSignedUrl(
            s3Client,
            new PutObjectCommand({
              Bucket: process.env.R2_BUCKET_NAME || "",
              Key: fileKey,
              ContentType: input.contentType,
            }),
            { expiresIn: 3600 } // 1 hour
          );

          console.log("[R2] Generated presigned upload URL for:", input.fileName);
          return {
            presignedUrl,
            fileKey,
            expiresIn: 3600,
          };
        } catch (error) {
          if (error instanceof TRPCError) throw error;
          console.error("[R2] Presigned URL error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to generate upload URL",
          });
        }
      }),

    /**
     * Generate presigned URL for file download
     */
    getDownloadUrl: publicProcedure
      .input(z.object({ fileKey: z.string().min(1) }))
      .mutation(async ({ input }) => {
        try {
          // Generate presigned download URL (7 days)
          const presignedUrl = await getSignedUrl(
            s3Client,
            new GetObjectCommand({
              Bucket: process.env.R2_BUCKET_NAME || "",
              Key: input.fileKey,
            }),
            { expiresIn: 604800 }
          );

          console.log("[R2] Generated download URL for:", input.fileKey);
          return {
            presignedUrl,
            expiresIn: 604800,
          };
        } catch (error) {
          console.error("[R2] Download URL error:", error);
          throw new TRPCError({
            code: "INTERNAL_SERVER_ERROR",
            message: "Failed to generate download URL",
          });
        }
      }),
  }),
});

export type AppRouter = typeof appRouter;
