import { v } from "convex/values";
import { internalMutation, mutation, query } from "./_generated/server";
import { split } from "./lib/split";
import { toOrder } from "./lib/shape";

export const createPending = internalMutation({
  args: { productId: v.id("products"), buyerId: v.id("users") },
  handler: async (ctx, { productId, buyerId }) => {
    const product = await ctx.db.get(productId);
    if (!product) throw new Error(`Product ${productId} not found`);
    const seller = await ctx.db.get(product.sellerId);
    const orderId = await ctx.db.insert("orders", {
      productId,
      productName: product.name,
      sellerId: product.sellerId,
      sellerName: seller?.name ?? "Unknown",
      buyerId,
      amountCents: product.priceCents,
      ...split(product.priceCents),
      status: "pending",
    });
    return {
      orderId,
      productName: product.name,
      amountCents: product.priceCents,
      productCheckoutUrl: product.checkoutUrl,
      whopAccountId: seller?.whopAccountId,
    };
  },
});

export const confirm = mutation({
  args: { id: v.id("orders") },
  handler: async (ctx, { id }) => {
    const order = await ctx.db.get(id);
    if (!order) throw new Error(`Order ${id} not found`);
    if (order.status !== "paid") await ctx.db.patch(id, { status: "paid" });
    return toOrder({ ...order, status: "paid" });
  },
});

export const bySeller = query({
  args: { sellerId: v.id("sellers") },
  handler: async (ctx, { sellerId }) =>
    (
      await ctx.db
        .query("orders")
        .withIndex("by_seller_status", (q) => q.eq("sellerId", sellerId).eq("status", "paid"))
        .order("desc")
        .collect()
    ).map(toOrder),
});
