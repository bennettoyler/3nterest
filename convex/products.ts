import { query } from "./_generated/server";
import { toProduct } from "./lib/shape";

export const list = query({
  args: {},
  handler: async (ctx) => {
    const products = await ctx.db.query("products").collect();
    return await Promise.all(products.map((p) => toProduct(ctx, p)));
  },
});
