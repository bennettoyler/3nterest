import { expect, test } from "vitest";
import { rankByFit } from "./match";

const product = (name: string, category: string, width: number, depth: number, height: number) => ({
  name,
  category,
  dimensions: { width, depth, height },
});

test("products of the category are ranked by size distance", () => {
  const products = [
    product("big sofa", "sofa", 2.6, 1.6, 0.8),
    product("chair", "chair", 0.7, 0.7, 0.85),
    product("small sofa", "sofa", 2.0, 0.9, 0.8),
  ];
  expect(rankByFit(products, "sofa", { width: 2.1, depth: 0.95, height: 0.8 }).map((p) => p.name)).toEqual(["small sofa", "big sofa"]);
  expect(rankByFit(products, "sofa").map((p) => p.name)).toEqual(["big sofa", "small sofa"]);
  expect(rankByFit(products, "bed", { width: 1.6, depth: 2, height: 0.9 })).toEqual([]);
});
