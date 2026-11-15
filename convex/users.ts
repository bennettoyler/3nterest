import { query } from "./_generated/server";
import { toUser } from "./lib/shape";

export const list = query({
  args: {},
  handler: async (ctx) => (await ctx.db.query("users").collect()).map(toUser),
});
