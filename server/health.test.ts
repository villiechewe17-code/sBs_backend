import { describe, expect, it } from "vitest";
import { appRouter } from "./routers";
import type { TrpcContext } from "./_core/context";

/**
 * Create a public context for testing
 */
function createPublicContext(): TrpcContext {
  const ctx: TrpcContext = {
    user: null,
    req: {
      protocol: "https",
      headers: {},
    } as TrpcContext["req"],
    res: {
      clearCookie: () => {},
    } as TrpcContext["res"],
  };

  return ctx;
}

describe("health check", () => {
  it("returns ok status", async () => {
    const ctx = createPublicContext();
    const caller = appRouter.createCaller(ctx);

    const result = await caller.health.check();

    expect(result).toHaveProperty("status");
    expect(result.status).toBe("ok");
    expect(result).toHaveProperty("timestamp");
    expect(result).toHaveProperty("service");
    expect(result.service).toBe("Content Management Backend");
  });
});

describe("R2 configuration", () => {
  it("has required R2 environment variables", () => {
    expect(process.env.R2_ACCOUNT_ID).toBeDefined();
    expect(process.env.R2_ACCESS_KEY_ID).toBeDefined();
    expect(process.env.R2_SECRET_ACCESS_KEY).toBeDefined();
    expect(process.env.R2_BUCKET_NAME).toBeDefined();

    // Verify they are not empty strings
    expect(process.env.R2_ACCOUNT_ID).not.toBe("");
    expect(process.env.R2_ACCESS_KEY_ID).not.toBe("");
    expect(process.env.R2_SECRET_ACCESS_KEY).not.toBe("");
    expect(process.env.R2_BUCKET_NAME).not.toBe("");
  });
});
