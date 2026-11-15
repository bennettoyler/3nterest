import { v } from "convex/values";
import { internalMutation } from "./_generated/server";
import type { Doc, Id } from "./_generated/dataModel";
import sampleRoom from "../Interest/Shared/SampleRoom.json";
import * as data from "./seedData";
import { rankByFit } from "./lib/match";

type Category = Doc<"products">["category"];
type Size = { width: number; depth: number; height: number };
const categories: Category[] = ["chair", "table", "sofa", "bed", "storage", "television", "other"];

const num = (x: unknown) => (typeof x === "number" && Number.isFinite(x) ? x : 0);
const size = (x: any): Size | undefined =>
  x && typeof x === "object" ? { width: num(x.width), depth: num(x.depth), height: num(x.height) } : undefined;
const surfaces = (xs: any) =>
  (Array.isArray(xs) ? xs : []).map((s: any) => ({
    transform: (Array.isArray(s?.transform) ? s.transform : []).map(num),
    width: num(s?.width),
    height: num(s?.height),
  }));

// A scan is a Room as JSONEncoder wrote it (LastScan.json). Only the shell and each placement's id,
// transform, category and scannedSize are kept; ownerId and productId are session-specific.
function roomTemplate(scan: any) {
  const fromScan = Boolean(scan && Array.isArray(scan.placements) && scan.shell);
  const room = fromScan ? scan : sampleRoom;
  return {
    fromScan,
    shell: { walls: surfaces(room.shell.walls), doors: surfaces(room.shell.doors), windows: surfaces(room.shell.windows) },
    placements: (room.placements as any[]).map((p, i) => ({
      id: typeof p.id === "string" && p.id ? p.id : `placement-${i}`,
      transform: (Array.isArray(p.transform) ? p.transform : []).map(num),
      category: categories.includes(p.category) ? (p.category as Category) : ("other" as Category),
      scannedSize: size(p.scannedSize),
    })),
  };
}

const clearedTables = ["orders", "collections", "rooms", "designs"] as const;

// Clears and reinserts the demo data. Users, sellers and products are upserted by name or slug, so
// their ids survive a reseed; rooms, designs, orders and collections are recreated. File URLs are
// cleared with storage; run seed/upload.mjs afterwards.
export const run = internalMutation({
  args: { scan: v.optional(v.any()) },
  handler: async (ctx, { scan }) => {
    for (const table of clearedTables) {
      for (const doc of await ctx.db.query(table).collect()) await ctx.db.delete(doc._id);
    }
    for (const file of await ctx.db.system.query("_storage").collect()) await ctx.storage.delete(file._id);

    const existingUsers = await ctx.db.query("users").collect();
    const userIds: Id<"users">[] = [];
    for (const name of data.users) {
      const id = existingUsers.find((u) => u.name === name)?._id ?? (await ctx.db.insert("users", { name }));
      userIds.push(id);
      await ctx.db.insert("collections", { userId: id, name: "Saved", roomIds: [], productIds: [] });
    }
    for (const u of existingUsers) if (!userIds.includes(u._id)) await ctx.db.delete(u._id);

    const existingSellers = await ctx.db.query("sellers").collect();
    const sellerIds = new Map<string, Id<"sellers">>();
    for (const s of data.sellers) {
      const fields = {
        name: s.name,
        kind: s.kind,
        whopAccountId: s.whopAccountId,
        userId: s.userIndex === undefined ? undefined : userIds[s.userIndex],
      };
      const existing = existingSellers.find((e) => e.name === s.name);
      if (existing) await ctx.db.patch(existing._id, fields);
      sellerIds.set(s.key, existing?._id ?? (await ctx.db.insert("sellers", fields)));
    }
    const keptSellers = [...sellerIds.values()];
    for (const s of existingSellers) if (!keptSellers.includes(s._id)) await ctx.db.delete(s._id);

    const existingProducts = await ctx.db.query("products").collect();
    const products: Doc<"products">[] = [];
    for (const p of data.products) {
      const fields = {
        slug: p.slug,
        sellerId: sellerIds.get(p.seller)!,
        name: p.name,
        category: p.category,
        priceCents: p.priceCents,
        dimensions: { width: p.size[0], depth: p.size[1], height: p.size[2] },
        vendorUrl: `https://example.com/p/${p.slug}`,
        modelUrl: undefined,
        thumbnailUrl: undefined,
        instructionsUrl: undefined,
        designId: undefined,
        checkoutUrl: undefined,
      };
      const existing = existingProducts.find((e) => e.slug === p.slug);
      if (existing) await ctx.db.patch(existing._id, fields);
      const id = existing?._id ?? (await ctx.db.insert("products", fields));
      products.push((await ctx.db.get(id))!);
    }
    for (const p of existingProducts) if (!products.some((k) => k._id === p._id)) await ctx.db.delete(p._id);

    const template = roomTemplate(scan);
    for (const [i, r] of data.rooms.entries()) {
      await ctx.db.insert("rooms", {
        slug: r.slug,
        ownerId: userIds[r.ownerIndex],
        title: r.title,
        published: true,
        shell: template.shell,
        placements: template.placements.map(({ scannedSize, ...p }) => {
          const ranked = rankByFit(products, p.category, scannedSize);
          const product = ranked[i % Math.max(ranked.length, 1)];
          return {
            ...p,
            ...(scannedSize ? { scannedSize } : {}),
            ...(product ? { productId: product._id as string } : {}),
          };
        }),
      });
    }

    return {
      source: template.fromScan ? "scan" : "SampleRoom.json",
      users: userIds.length,
      sellers: sellerIds.size,
      products: products.length,
      rooms: data.rooms.length,
      placementsPerRoom: template.placements.length,
    };
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

// Removes what the demo reset's smoke checks created.
export const deleteSmoke = internalMutation({
  args: { orderId: v.id("orders"), designId: v.id("designs") },
  handler: async (ctx, { orderId, designId }) => {
    await ctx.db.delete(orderId);
    await ctx.db.delete(designId);
    return null;
  },
});
