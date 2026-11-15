// Decides whether an order may be marked paid. An order created through the real Whop path carries its
// checkout configuration (and the variant Whop created for it), so its payment can be looked up exactly:
// paid only when Whop lists a payment for that checkout configuration with status "paid" that was not
// refunded. Orders without one (fallback checkout link), a missing WHOP_API_KEY, or a Whop that does not
// answer with a usable response in time cannot be verified; the caller then keeps the old behaviour and
// marks the order paid so the demo never dead-ends.

export type Verdict =
  | { result: "paid"; paymentId: string }
  | { result: "not_found" }
  | { result: "unverified"; reason: "fallback_checkout" | "no_api_key" | "whop_unreachable"; detail?: string };

export type CheckoutRef = {
  orderId: string;
  createdAtMs: number;
  whopCheckoutId?: string;
  whopVariantId?: string;
  whopAccountId?: string;
};

type Payment = {
  id?: string;
  status?: string;
  substatus?: string;
  checkout_configuration_id?: string | null;
  metadata?: Record<string, unknown> | null;
};

const REFUNDED = new Set(["refunded", "auto_refunded"]);

export async function verifyPayment(
  order: CheckoutRef,
  env: { apiKey?: string; apiBase?: string },
  fetchFn: typeof fetch = fetch,
  timeoutMs = 4000,
): Promise<Verdict> {
  if (!order.whopCheckoutId) return { result: "unverified", reason: "fallback_checkout" };
  if (!env.apiKey) return { result: "unverified", reason: "no_api_key" };

  const params = new URLSearchParams({
    status: "paid",
    created_after: new Date(order.createdAtMs - 60_000).toISOString(),
    first: "100",
  });
  if (order.whopAccountId) params.set("account_id", order.whopAccountId);
  if (order.whopVariantId) params.set("variant_id", order.whopVariantId);

  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetchFn(`${env.apiBase ?? "https://api.whop.com/api/v1"}/payments?${params}`, {
      signal: controller.signal,
      headers: { Authorization: `Bearer ${env.apiKey}` },
    });
    if (!res.ok) return { result: "unverified", reason: "whop_unreachable", detail: `HTTP ${res.status}` };
    const body = (await res.json()) as { data?: Payment[] };
    const payment = (body.data ?? []).find(
      (p) =>
        p.status === "paid" &&
        !REFUNDED.has(p.substatus ?? "") &&
        (p.checkout_configuration_id === order.whopCheckoutId || p.metadata?.orderId === order.orderId),
    );
    return payment?.id ? { result: "paid", paymentId: payment.id } : { result: "not_found" };
  } catch (error) {
    return { result: "unverified", reason: "whop_unreachable", detail: String(error) };
  } finally {
    clearTimeout(timer);
  }
}
