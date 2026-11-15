// Decides whether an order may be marked paid. An order created through the real Whop path carries its
// checkout configuration and the variant Whop created for it. Its seller sub-account's paid payments since
// the order was created are listed, and the order is paid when one of them, not refunded or lost in a
// dispute, links to it: its checkout_configuration_id is the order's, or its metadata.orderId is the order,
// or, only for a payment carrying neither link, its variant_id is the order's. Whop reuses a variant across
// checkout configurations for the same product, so a variant match alone could be another order's payment;
// orders:markPaid therefore lets one payment confirm only one order. Orders without one (fallback checkout link), a missing WHOP_API_KEY, or a
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
  variant_id?: string | null;
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
    const paid = (Array.isArray(body?.data) ? body.data : []).filter(
      (p) => p.id && p.status === "paid" && !REVERSED.has(p.substatus ?? ""),
    );
    const payment =
      paid.find((p) => p.checkout_configuration_id === order.whopCheckoutId || p.metadata?.orderId === order.orderId) ??
      paid.find(
        (p) =>
          order.whopVariantId &&
          p.variant_id === order.whopVariantId &&
          !p.checkout_configuration_id &&
          p.metadata?.orderId === undefined,
      );
    return payment?.id ? { result: "paid", paymentId: payment.id } : { result: "not_found" };
  } finally {
    clearTimeout(timer);
  }
}
