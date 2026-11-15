// Decides whether an order may be marked paid. An order created through the real Whop path carries its
// checkout configuration (and the variant Whop created for it), so its payment can be looked up exactly:
// paid only when Whop lists a payment for that checkout configuration with status "paid" that was not
// refunded or lost in a dispute. Orders without one (fallback checkout link), a missing WHOP_API_KEY, or a
// Whop that does not answer in time (network error, timeout, 5xx) cannot be verified; the caller then keeps
// the old behaviour and marks the order paid so the demo never dead-ends. Every other answer that is not a
// readable list (any 4xx including 429, an unparsable body) is treated as no payment found, so neither a
// broken key nor a buyer hammering confirm into a rate limit turns an unpaid order into a paid one.

export type Verdict =
  | { result: "paid"; paymentId: string }
  | { result: "not_found"; detail?: string }
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

const REVERSED = new Set(["refunded", "auto_refunded", "dispute_lost", "resolution_lost"]);

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
    }).catch((error) => error as Error);
    if (res instanceof Error) return { result: "unverified", reason: "whop_unreachable", detail: String(res) };
    if (res.status >= 500) return { result: "unverified", reason: "whop_unreachable", detail: `HTTP ${res.status}` };
    if (!res.ok) return { result: "not_found", detail: `Whop refused the lookup: HTTP ${res.status}` };
    const body = (await res.json().catch((error) => error as Error)) as { data?: Payment[] } | Error;
    if (body instanceof Error) {
      return controller.signal.aborted
        ? { result: "unverified", reason: "whop_unreachable", detail: String(body) }
        : { result: "not_found", detail: "Whop answered with an unreadable body" };
    }
    const payment = (body.data ?? []).find(
      (p) =>
        p.status === "paid" &&
        !REVERSED.has(p.substatus ?? "") &&
        (p.checkout_configuration_id === order.whopCheckoutId || p.metadata?.orderId === order.orderId),
    );
    return payment?.id ? { result: "paid", paymentId: payment.id } : { result: "not_found" };
  } finally {
    clearTimeout(timer);
  }
}
