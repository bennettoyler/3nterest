import { v } from "convex/values";
import { internalMutation, internalQuery } from "./_generated/server";
import type { Doc, Id } from "./_generated/dataModel";
import sampleRoom from "../Interest/Shared/SampleRoom.json";
import * as data from "./seedData";
import { rankByFit, sizeDistance } from "./lib/match";

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

// Upserts the seeded users, sellers and products by name or slug, keeping their ids and file URLs, and
// inserts any missing seeded room. Existing seeded rooms are left as they are, because the app can save
// over them; replaceRooms rebuilds them from the scan. Rows the app created are never touched.
// Run seed/upload.mjs afterwards to attach new files.
export const run = internalMutation({
  args: { scan: v.optional(v.any()), replaceRooms: v.optional(v.boolean()) },
  handler: async (ctx, { scan, replaceRooms }) => {
    const existingUsers = await ctx.db.query("users").collect();
    const userIds: Id<"users">[] = [];
    for (const name of data.users) {
      const id = existingUsers.find((u) => u.name === name)?._id ?? (await ctx.db.insert("users", { name }));
      userIds.push(id);
      const collections = await ctx.db
        .query("collections")
        .withIndex("by_user", (q) => q.eq("userId", id))
        .collect();
      if (!collections.some((c) => c.name === "Saved")) {
        await ctx.db.insert("collections", { userId: id, name: "Saved", roomIds: [], productIds: [] });
      }
    }

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
      };
      const existing = await ctx.db
        .query("products")
        .withIndex("by_slug", (q) => q.eq("slug", p.slug))
        .unique();
      if (existing) await ctx.db.patch(existing._id, fields);
      const id = existing?._id ?? (await ctx.db.insert("products", fields));
      products.push((await ctx.db.get(id))!);
    }

    const template = roomTemplate(scan);
    const slugs = new Set(data.rooms.map((r) => r.slug));
    for (const room of await ctx.db.query("rooms").collect()) {
      if (room.slug && !slugs.has(room.slug)) await ctx.db.delete(room._id);
    }
    for (const [i, r] of data.rooms.entries()) {
      const fields = {
        slug: r.slug,
        ownerId: userIds[r.ownerIndex],
        title: r.title,
        published: true,
        shell: template.shell,
        placements: template.placements.map(({ scannedSize, ...p }) => {
          const ranked = rankByFit(products, p.category, scannedSize).filter(
            (product) => p.category !== "other" || !scannedSize || sizeDistance(product.dimensions, scannedSize) <= 0.5,
          );
          const product = ranked[i % Math.max(ranked.length, 1)];
          return {
            ...p,
            ...(scannedSize ? { scannedSize } : {}),
            ...(product ? { productId: product._id as string } : {}),
          };
        }),
      };
      const existing = await ctx.db
        .query("rooms")
        .withIndex("by_slug", (q) => q.eq("slug", r.slug))
        .unique();
      if (!existing) await ctx.db.insert("rooms", fields);
      else if (replaceRooms) await ctx.db.patch(existing._id, fields);
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

// Task Z full reset: deletes every row and stored file, including what the app created. Follow it
// with seed:run and seed/upload.mjs in the same command (npm run demo:reset -- --full).
export const wipeAll = internalMutation({
  args: {},
  handler: async (ctx) => {
    const tables = ["orders", "collections", "rooms", "designs", "products", "sellers", "users"] as const;
    for (const table of tables) {
      for (const doc of await ctx.db.query(table).collect()) await ctx.db.delete(doc._id);
    }
    for (const file of await ctx.db.system.query("_storage").collect()) await ctx.storage.delete(file._id);
    return null;
  },
});

const fileArgs = {
  table: v.union(v.literal("products"), v.literal("rooms")),
  slug: v.string(),
  field: v.union(v.literal("modelUrl"), v.literal("thumbnailUrl"), v.literal("instructionsUrl")),
};

// True when the row exists and its field is still empty, so upload.mjs only uploads what is missing.
export const needsFile = internalQuery({
  args: fileArgs,
  handler: async (ctx, { table, slug, field }) => {
    const doc = await ctx.db
      .query(table)
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .unique();
    return Boolean(doc && !(doc as Record<string, unknown>)[field]);
  },
});

export const attachFile = internalMutation({
  args: { ...fileArgs, storageId: v.id("_storage") },
  handler: async (ctx, { table, slug, field, storageId }) => {
    const doc = await ctx.db
      .query(table)
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .unique();
    const url = await ctx.storage.getUrl(storageId);
    if (!doc || !url || (table === "rooms" && field !== "thumbnailUrl")) {
      await ctx.storage.delete(storageId);
      return null;
    }
    await ctx.db.patch(doc._id, { [field]: url });
    return url;
  },
});

// Seeded rooms in the feed and how many lack a thumbnail, for the demo reset's checks.
export const status = internalQuery({
  args: {},
  handler: async (ctx) => {
    const seeded = (await ctx.db.query("rooms").collect()).filter((r) => r.slug && r.published);
    return { seededRooms: seeded.length, seededWithoutThumbnail: seeded.filter((r) => !r.thumbnailUrl).length };
  },
});

// Removes what the demo reset's smoke checks created.
export const deleteSmoke = internalMutation({
  args: { orderId: v.optional(v.id("orders")), designId: v.id("designs") },
  handler: async (ctx, { orderId, designId }) => {
    if (orderId) await ctx.db.delete(orderId);
    await ctx.db.delete(designId);
    return null;
  },
});
