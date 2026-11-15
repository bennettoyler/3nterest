import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { toCollection } from "./lib/shape";

export const mine = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) =>
    (
      await ctx.db
        .query("collections")
        .withIndex("by_user", (q) => q.eq("userId", userId))
        .collect()
    ).map(toCollection),
});

const optionalId = v.optional(v.union(v.string(), v.null()));

export const save = mutation({
  args: { roomId: optionalId, productId: optionalId, userId: v.id("users") },
  handler: async (ctx, args) => {
    const { userId } = args;
    const roomId = args.roomId ? ctx.db.normalizeId("rooms", args.roomId) : null;
    const productId = args.productId ? ctx.db.normalizeId("products", args.productId) : null;
    const saved = (
      await ctx.db
        .query("collections")
        .withIndex("by_user", (q) => q.eq("userId", userId))
        .collect()
    ).find((c) => c.name === "Saved");
    const add = (ids: string[], id?: string | null) => (id && !ids.includes(id) ? [...ids, id] : ids);
    if (saved) {
      await ctx.db.patch(saved._id, {
        roomIds: add(saved.roomIds, roomId),
        productIds: add(saved.productIds, productId),
      });
    } else {
      await ctx.db.insert("collections", {
        userId,
        name: "Saved",
        roomIds: add([], roomId),
        productIds: add([], productId),
      });
    }
    return null;
  },
});
