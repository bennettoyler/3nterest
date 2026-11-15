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
  expect(url.searchParams.get("variant_id")).toBe("plan_1");
  expect(url.searchParams.get("status")).toBe("paid");
});

test("paid: matched by metadata.orderId", async () => {
  const fetchFn = respond(200, { data: [{ id: "pay_2", status: "paid", checkout_configuration_id: null, metadata: { orderId: "ord1" } }] });
  expect(await verifyPayment(order, env, fetchFn)).toEqual({ result: "paid", paymentId: "pay_2" });
});

test("not found: no payments, another checkout's payment, unpaid or refunded payments", async () => {
  expect(await verifyPayment(order, env, respond(200, { data: [] }))).toEqual({ result: "not_found" });
  const others = [
    { id: "pay_3", status: "paid", checkout_configuration_id: "ch_other" },
    { id: "pay_4", status: "open", checkout_configuration_id: "ch_1" },
    { id: "pay_5", status: "paid", substatus: "refunded", checkout_configuration_id: "ch_1" },
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

test("Whop error response or network failure: unverified", async () => {
  expect(await verifyPayment(order, env, respond(503, {}))).toMatchObject({ result: "unverified", reason: "whop_unreachable", detail: "HTTP 503" });
  const down = (async () => {
    throw new TypeError("fetch failed");
  }) as typeof fetch;
  expect(await verifyPayment(order, env, down)).toMatchObject({ result: "unverified", reason: "whop_unreachable" });
});
