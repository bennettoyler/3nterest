import { expect, test } from "vitest";
import { split } from "./split";

test("5% cut, rounded, and the parts sum to the whole", () => {
  expect(split(4999)).toEqual({ platformFeeCents: 250, sellerCents: 4749 });
  expect(split(1000)).toEqual({ platformFeeCents: 50, sellerCents: 950 });
  expect(split(0)).toEqual({ platformFeeCents: 0, sellerCents: 0 });
});
