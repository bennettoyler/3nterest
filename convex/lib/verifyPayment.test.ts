import { expect, test } from "vitest";
import { verifyPayment, type CheckoutRef } from "./verifyPayment";

const order: CheckoutRef = {
  orderId: "ord1",
  createdAtMs: Date.parse("2026-11-15T20:00:00Z"),
  whopCheckoutId: "ch_1",
  whopVariantId: "plan_1",
  whopAccountId: "biz_seller",
};
const env = { apiKey: "key", apiBase: "https://whop.test/api/v1" };

const respond = (status: number, body: unknown, seen?: string[]) =>
  (async (url: string | URL | Request) => {
    seen?.push(String(url));
    return new Response(JSON.stringify(body), { status });
  }) as typeof fetch;

test("paid: a paid payment for the checkout configuration", async () => {
  const seen: string[] = [];
  const fetchFn = respond(200, { data: [{ id: "pay_1", status: "paid", substatus: "succeeded", checkout_configuration_id: "ch_1" }] }, seen);
  expect(await verifyPayment(order, env, fetchFn)).toEqual({ result: "paid", paymentId: "pay_1" });
  const url = new URL(seen[0]);
  expect(url.pathname).toBe("/api/v1/payments");
  expect(url.searchParams.get("account_id")).toBe("biz_seller");
  expect(url.searchParams.has("variant_id")).toBe(false);
  expect(url.searchParams.get("status")).toBe("paid");
});

test("paid: matched by metadata.orderId", async () => {
  const fetchFn = respond(200, { data: [{ id: "pay_2", status: "paid", checkout_configuration_id: null, metadata: { orderId: "ord1" } }] });
  expect(await verifyPayment(order, env, fetchFn)).toEqual({ result: "paid", paymentId: "pay_2" });
});

test("paid: matched by variant_id when the payment carries no checkout configuration or orderId", async () => {
  const fetchFn = respond(200, { data: [{ id: "pay_v", status: "paid", variant_id: "plan_1", checkout_configuration_id: null, metadata: null }] });
  expect(await verifyPayment(order, env, fetchFn)).toEqual({ result: "paid", paymentId: "pay_v" });
});

test("paid: an exact checkout configuration match wins over a variant-only match", async () => {
  const data = [
    { id: "pay_v", status: "paid", variant_id: "plan_1" },
    { id: "pay_ch", status: "paid", variant_id: "plan_1", checkout_configuration_id: "ch_1" },
  ];
  expect(await verifyPayment(order, env, respond(200, { data }))).toEqual({ result: "paid", paymentId: "pay_ch" });
});

test("not found: another order's payment on the same account and variant", async () => {
  const data = [
    { id: "pay_a", status: "paid", variant_id: "plan_1", checkout_configuration_id: "ch_other" },
    { id: "pay_b", status: "paid", variant_id: "plan_1", metadata: { orderId: "ord_other" } },
    { id: "pay_c", status: "paid", variant_id: "plan_other" },
  ];
  expect(await verifyPayment(order, env, respond(200, { data }))).toEqual({ result: "not_found" });
});

test("not found: a 200 whose JSON is not a list of payments", async () => {
  expect(await verifyPayment(order, env, respond(200, null))).toEqual({ result: "not_found" });
  expect(await verifyPayment(order, env, respond(200, { data: "x" }))).toEqual({ result: "not_found" });
});

test("not found: no payments, another checkout's payment, unpaid or refunded payments", async () => {
  expect(await verifyPayment(order, env, respond(200, { data: [] }))).toEqual({ result: "not_found" });
  const others = [
    { id: "pay_3", status: "paid", checkout_configuration_id: "ch_other" },
    { id: "pay_4", status: "open", checkout_configuration_id: "ch_1" },
    { id: "pay_5", status: "paid", substatus: "refunded", checkout_configuration_id: "ch_1" },
    { id: "pay_6", status: "paid", substatus: "dispute_lost", checkout_configuration_id: "ch_1" },
    { id: "pay_7", status: "paid", substatus: "resolution_lost", checkout_configuration_id: "ch_1" },
  ];
  expect(await verifyPayment(order, env, respond(200, { data: others }))).toEqual({ result: "not_found" });
});

test("fallback order: no checkout configuration, Whop is not called", async () => {
  const seen: string[] = [];
  expect(await verifyPayment({ ...order, whopCheckoutId: undefined }, env, respond(200, { data: [] }, seen))).toEqual({
    result: "unverified",
    reason: "fallback_checkout",
  });
  expect(seen).toEqual([]);
});

test("key unset: unverified, Whop is not called", async () => {
  const seen: string[] = [];
  expect(await verifyPayment(order, { apiKey: undefined }, respond(200, { data: [] }, seen))).toEqual({
    result: "unverified",
    reason: "no_api_key",
  });
  expect(seen).toEqual([]);
});

test("Whop timeout: aborted after the timeout and unverified", async () => {
  const hang = ((_url: string | URL | Request, init?: RequestInit) =>
    new Promise((_, reject) => init?.signal?.addEventListener("abort", () => reject(new Error("aborted"))))) as typeof fetch;
  const start = Date.now();
  const verdict = await verifyPayment(order, env, hang, 50);
  expect(verdict).toMatchObject({ result: "unverified", reason: "whop_unreachable" });
  expect(Date.now() - start).toBeLessThan(1000);
});

test("Whop refuses the lookup (401, 403, 400, 429): not found, never paid", async () => {
  for (const status of [401, 403, 400, 429]) {
    expect(await verifyPayment(order, env, respond(status, {}))).toMatchObject({ result: "not_found" });
  }
});

test("Whop answers 200 with an unreadable body: not found", async () => {
  const html = (async () => new Response("<html>proxy error</html>", { status: 200 })) as typeof fetch;
  expect(await verifyPayment(order, env, html)).toMatchObject({ result: "not_found" });
});

test("Whop 5xx or network failure: unverified", async () => {
  expect(await verifyPayment(order, env, respond(503, {}))).toMatchObject({ result: "unverified", reason: "whop_unreachable", detail: "HTTP 503" });
  const down = (async () => {
    throw new TypeError("fetch failed");
  }) as typeof fetch;
  expect(await verifyPayment(order, env, down)).toMatchObject({ result: "unverified", reason: "whop_unreachable" });
});
