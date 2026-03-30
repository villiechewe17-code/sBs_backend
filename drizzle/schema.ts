import { int, mysqlEnum, mysqlTable, text, timestamp, varchar, bigint, boolean } from "drizzle-orm/mysql-core";
import { relations } from "drizzle-orm";

/**
 * Core user table backing auth flow.
 * Extend this file with additional tables as your product grows.
 * Columns use camelCase to match both database fields and generated types.
 */
export const users = mysqlTable("users", {
  /**
   * Surrogate primary key. Auto-incremented numeric value managed by the database.
   * Use this for relations between tables.
   */
  id: int("id").autoincrement().primaryKey(),
  /** Manus OAuth identifier (openId) returned from the OAuth callback. Unique per user. */
  openId: varchar("openId", { length: 64 }).notNull().unique(),
  name: text("name"),
  email: varchar("email", { length: 320 }),
  loginMethod: varchar("loginMethod", { length: 64 }),
  role: mysqlEnum("role", ["user", "admin"]).default("user").notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
  lastSignedIn: timestamp("lastSignedIn").defaultNow().notNull(),
});

export type User = typeof users.$inferSelect;
export type InsertUser = typeof users.$inferInsert;

/**
 * Categories table for organizing content
 */
export const categories = mysqlTable("categories", {
  id: int("id").autoincrement().primaryKey(),
  name: varchar("name", { length: 255 }).notNull(),
  description: text("description"),
  icon: varchar("icon", { length: 255 }),
  displayOrder: int("display_order").default(0).notNull(),
  isActive: boolean("is_active").default(true).notNull(),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Category = typeof categories.$inferSelect;
export type InsertCategory = typeof categories.$inferInsert;

/**
 * Content table for storing content metadata
 * Files are stored in R2, only metadata is stored here
 */
export const content = mysqlTable("content", {
  id: int("id").autoincrement().primaryKey(),
  categoryId: int("category_id").notNull(),
  title: varchar("title", { length: 255 }).notNull(),
  description: text("description"),
  contentType: mysqlEnum("content_type", ["folder", "link", "image", "text"]).notNull(),
  accessLevel: mysqlEnum("access_level", ["free", "paid"]).default("free").notNull(),
  isActive: boolean("is_active").default(true).notNull(),
  r2FileKey: varchar("r2_file_key", { length: 512 }),
  r2Url: varchar("r2_url", { length: 512 }),
  fileSize: bigint("file_size", { mode: "number" }),
  mimeType: varchar("mime_type", { length: 100 }),
  externalUrl: varchar("external_url", { length: 512 }),
  textContent: text("text_content"),
  uploadedBy: int("uploaded_by"),
  createdAt: timestamp("createdAt").defaultNow().notNull(),
  updatedAt: timestamp("updatedAt").defaultNow().onUpdateNow().notNull(),
});

export type Content = typeof content.$inferSelect;
export type InsertContent = typeof content.$inferInsert;

/**
 * Relations
 */
export const categoriesRelations = relations(categories, ({ many }) => ({
  content: many(content),
}));

export const contentRelations = relations(content, ({ one }) => ({
  category: one(categories, {
    fields: [content.categoryId],
    references: [categories.id],
  }),
  uploadedByUser: one(users, {
    fields: [content.uploadedBy],
    references: [users.id],
  }),
}));