import { v } from "convex/values";
import { action } from "./_generated/server";
import { internal } from "./_generated/api";
import { split } from "./lib/split";

const TIMEOUT_MS = 8000;

// The app opens checkoutUrl in SFSafariViewController, which crashes on anything but http(s).
const https = (url?: string | null) => (url && /^https:\/\/[^\s]+$/.test(url) ? url : null);

// Real path: a Whop checkout configuration charged directly on the seller's sub-account with the
// 5% platform cut as application_fee_amount (docs.whop.com, "Collect Payments for Subaccounts").
// Runs only when WHOP_API_KEY is set and the seller has a whopAccountId; any failure falls back.
// No redirect_url: Whop accepts only https redirects, so the app confirms the order from its Done button.
async function whopCheckout(order: {
  orderId: string;
  productName: string;
  amountCents: number;
  whopAccountId?: string;
}): Promise<string | null> {
  const apiKey = process.env.WHOP_API_KEY;
  const { platformFeeCents } = split(order.amountCents);
  if (!apiKey || !order.whopAccountId || platformFeeCents <= 0) return null;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch(`${process.env.WHOP_API_BASE ?? "https://api.whop.com/api/v1"}/checkout_configurations`, {
      method: "POST",
      signal: controller.signal,
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
        "Idempotency-Key": order.orderId,
      },
      body: JSON.stringify({
        account_id: order.whopAccountId,
        metadata: { orderId: order.orderId },
        variant: {
          title: order.productName,
          initial_price: order.amountCents / 100,
          currency: "usd",
          billing_type: "one_time",
          application_fee_amount: platformFeeCents / 100,
        },
      }),
    });
    if (!res.ok) {
      console.warn(`Whop returned ${res.status}: ${await res.text()}`);
      return null;
    }
    const body = await res.json();
    return https(body?.purchase_url);
  } catch (error) {
    console.warn("Whop checkout failed, using fallback link:", String(error));
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export const createCheckout = action({
  args: { productId: v.id("products"), buyerId: v.id("users") },
  handler: async (ctx, { productId, buyerId }): Promise<{ orderId: string; checkoutUrl: string }> => {
    const order = await ctx.runMutation(internal.orders.createPending, { productId, buyerId });
    const checkoutUrl =
      (await whopCheckout(order)) ??
      https(order.productCheckoutUrl) ??
      https(process.env.WHOP_FALLBACK_CHECKOUT_URL) ??
      `https://example.com/checkout?order=${order.orderId}`;
    return { orderId: order.orderId, checkoutUrl };
  },
});
