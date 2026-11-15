import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import type { Id } from "./_generated/dataModel";
import sampleRoom from "../Interest/Shared/SampleRoom.json";
import * as data from "./seedData";

const tables = ["orders", "collections", "rooms", "products", "designs", "sellers", "users"] as const;

export const run = internalMutation({
  args: {},
  handler: async (ctx) => {
    for (const table of tables) {
      for (const doc of await ctx.db.query(table).collect()) await ctx.db.delete(doc._id);
    }
    for (const file of await ctx.db.system.query("_storage").collect()) await ctx.storage.delete(file._id);

    const userIds: Id<"users">[] = [];
    for (const name of data.users) {
      const id = await ctx.db.insert("users", { name });
      userIds.push(id);
      await ctx.db.insert("collections", { userId: id, name: "Saved", roomIds: [], productIds: [] });
    }

    const sellerIds = new Map<string, Id<"sellers">>();
    for (const s of data.sellers) {
      sellerIds.set(
        s.key,
        await ctx.db.insert("sellers", {
          name: s.name,
          kind: s.kind,
          ...(s.userIndex === undefined ? {} : { userId: userIds[s.userIndex] }),
        }),
      );
    }

    const productIds = new Map<string, Id<"products">>();
    for (const p of data.products) {
      productIds.set(
        p.slug,
        await ctx.db.insert("products", {
          slug: p.slug,
          sellerId: sellerIds.get(p.seller)!,
          name: p.name,
          category: p.category,
          priceCents: p.priceCents,
          dimensions: { width: p.size[0], depth: p.size[1], height: p.size[2] },
          vendorUrl: `https://example.com/p/${p.slug}`,
        }),
      );
    }

    for (const r of data.rooms) {
      await ctx.db.insert("rooms", {
        slug: r.slug,
        ownerId: userIds[r.ownerIndex],
        title: r.title,
        published: true,
        shell: sampleRoom.shell,
        placements: sampleRoom.placements.map((p) => {
          const category = p.category as keyof typeof r.picks;
          const slug = r.picks[category];
          return {
            id: p.id,
            transform: p.transform,
            category,
            ...(slug ? { productId: productIds.get(slug)! } : {}),
          };
        }),
      });
    }

    return { users: userIds.length, sellers: sellerIds.size, products: productIds.size, rooms: data.rooms.length };
  },
});

export const attachFile = internalMutation({
  args: {
    table: v.union(v.literal("products"), v.literal("rooms")),
    slug: v.string(),
    field: v.union(v.literal("modelUrl"), v.literal("thumbnailUrl"), v.literal("instructionsUrl")),
    storageId: v.id("_storage"),
  },
  handler: async (ctx, { table, slug, field, storageId }) => {
    const url = await ctx.storage.getUrl(storageId);
    if (!url) throw new Error(`No file ${storageId}`);
    const doc = await ctx.db
      .query(table)
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .unique();
    if (!doc) return null;
    if (table === "rooms" && field !== "thumbnailUrl") throw new Error("Rooms only take thumbnails");
    await ctx.db.patch(doc._id, { [field]: url });
    return url;
  },
});
