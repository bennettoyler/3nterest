import { ConvexError, v } from "convex/values";
import { action, internalMutation, internalQuery, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { split } from "./lib/split";
import { toOrder } from "./lib/shape";
import { verifyPayment } from "./lib/verifyPayment";

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

// Records the Whop checkout configuration createCheckout made for this order, so confirm can look up
// its payment exactly. Only fills fields the order does not have yet.
export const attachCheckout = internalMutation({
  args: { id: v.id("orders"), whopCheckoutId: v.string(), whopVariantId: v.optional(v.string()), whopAccountId: v.string() },
  handler: async (ctx, { id, ...fields }) => {
    const order = await ctx.db.get(id);
    if (!order || order.whopCheckoutId) return;
    await ctx.db.patch(id, fields);
  },
});

export const get = internalQuery({
  args: { id: v.id("orders") },
  handler: async (ctx, { id }) => await ctx.db.get(id),
});

export const markPaid = internalMutation({
  args: { id: v.id("orders"), whopPaymentId: v.optional(v.string()) },
  handler: async (ctx, { id, whopPaymentId }) => {
    const order = await ctx.db.get(id);
    if (!order) throw new Error(`Order ${id} not found`);
    if (order.status === "paid") return toOrder(order);
    if (whopPaymentId) {
      const claimed = await ctx.db
        .query("orders")
        .withIndex("by_whop_payment", (q) => q.eq("whopPaymentId", whopPaymentId))
        .first();
      if (claimed && claimed._id !== id) return null;
    }
    const patch = { status: "paid" as const, ...(whopPaymentId ? { whopPaymentId } : {}) };
    await ctx.db.patch(id, patch);
    return toOrder({ ...order, ...patch });
  },
});

// The app's "I've paid" button. An order from the real Whop path is marked paid only when Whop lists a
// paid payment for its checkout configuration; otherwise it stays pending and this throws a ConvexError
// containing PAYMENT_NOT_FOUND (ConvexError, because production redacts plain error messages). Orders
// that used the fallback link, a missing WHOP_API_KEY, or a Whop that does not answer within 4 s (or
// answers 5xx) are marked paid as before, with a warning in the logs, so the demo never dead-ends.
export const confirm = action({
  args: { id: v.id("orders") },
  handler: async (ctx, { id }): Promise<ReturnType<typeof toOrder>> => {
    const order = await ctx.runQuery(internal.orders.get, { id });
    if (!order) throw new Error(`Order ${id} not found`);
    if (order.status === "paid") return toOrder(order);
    const verdict = await verifyPayment(
      { ...order, orderId: id, createdAtMs: order._creationTime },
      { apiKey: process.env.WHOP_API_KEY, apiBase: process.env.WHOP_API_BASE },
    );
    if (verdict.result === "not_found") {
      console.log(`Order ${id}: no paid Whop payment for ${order.whopCheckoutId}${verdict.detail ? ` (${verdict.detail})` : ""}, left pending`);
      throw new ConvexError(`PAYMENT_NOT_FOUND: no successful Whop payment for order ${id} yet`);
    }
    if (verdict.result === "unverified") {
      console.warn(`Order ${id}: payment not verified (${verdict.reason}${verdict.detail ? `: ${verdict.detail}` : ""}), marked paid`);
    }
    const paid = await ctx.runMutation(internal.orders.markPaid, {
      id,
      whopPaymentId: verdict.result === "paid" ? verdict.paymentId : undefined,
    });
    if (!paid) {
      console.log(`Order ${id}: Whop payment already confirmed another order, left pending`);
      throw new ConvexError(`PAYMENT_NOT_FOUND: no successful Whop payment for order ${id} yet`);
    }
    return paid;
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
