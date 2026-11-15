import { v } from "convex/values";
import { query } from "./_generated/server";
import { toSeller } from "./lib/shape";

export const forUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, { userId }) => {
    const seller = await ctx.db
      .query("sellers")
      .withIndex("by_user", (q) => q.eq("userId", userId))
      .first();
    return seller ? toSeller(seller) : null;
  },
});
