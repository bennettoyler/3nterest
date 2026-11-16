import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { dimensions } from "./schema";
import { toProduct } from "./lib/shape";

export const list = query({
  args: {},
  handler: async (ctx) => {
    const products = await ctx.db.query("products").collect();
    return await Promise.all(products.map((p) => toProduct(ctx, p)));
  },
});

// A user-scanned object becomes a real product so it survives rooms:save and shows in the feed.
// Like seeded products, modelUrl/thumbnailUrl hold resolved storage URLs (ctx.storage.getUrl), not storage ids.
export const createScanned = mutation({
  args: {
    name: v.string(),
    dimensions,
    modelStorageId: v.string(),
    thumbnailStorageId: v.optional(v.string()),
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    const userId = ctx.db.normalizeId("users", args.userId);
    const user = userId ? await ctx.db.get(userId) : null;
    if (!userId || !user) throw new Error(`User ${args.userId} was never saved to Convex; cannot create a scanned product`);
    const modelStorageId = ctx.db.system.normalizeId("_storage", args.modelStorageId);
    const modelUrl = modelStorageId ? await ctx.storage.getUrl(modelStorageId) : null;
    if (!modelUrl) throw new Error(`Model file ${args.modelStorageId} was not found in storage`);
    const thumbnailStorageId = args.thumbnailStorageId ? ctx.db.system.normalizeId("_storage", args.thumbnailStorageId) : null;
    const thumbnailUrl = thumbnailStorageId ? ((await ctx.storage.getUrl(thumbnailStorageId)) ?? undefined) : undefined;

    const existing = await ctx.db.query("sellers").withIndex("by_user", (q) => q.eq("userId", userId)).first();
    const sellerId = existing?._id ?? (await ctx.db.insert("sellers", { name: user.name, kind: "creator", userId }));

    const clamp = (n: number) => Math.max(0.01, n);
    const productId = await ctx.db.insert("products", {
      sellerId,
      name: args.name,
      category: "other",
      priceCents: 0,
      dimensions: {
        width: clamp(args.dimensions.width),
        depth: clamp(args.dimensions.depth),
        height: clamp(args.dimensions.height),
      },
      modelUrl,
      ...(thumbnailUrl ? { thumbnailUrl } : {}),
    });
    return await toProduct(ctx, (await ctx.db.get(productId))!);
  },
});
