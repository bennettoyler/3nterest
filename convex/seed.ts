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

// Room i takes the i-th best-fitting product of the placement's category. With fit, a product must also
// fit the scanned footprint (at most 30% + 10 cm wider or deeper), so a dining table never lands in a
// coffee-table spot; an "other" product must be within 0.5 m of the scanned size. Without fit, this is
// the rule earlier seeds used, which seed:correctSeeded needs to recognise their picks.
function fitsSpot(product: Doc<"products">, scannedSize: Size | undefined) {
  const fits = (a: number, b: number) => a <= b * 1.3 + 0.1;
  return !scannedSize || (fits(product.dimensions.width, scannedSize.width) && fits(product.dimensions.depth, scannedSize.depth));
}

function pick(products: Doc<"products">[], category: Category, scannedSize: Size | undefined, i: number, fit: boolean) {
  const ranked = rankByFit(products, category, scannedSize).filter((product) => {
    if (!scannedSize) return true;
    if (category === "other") return sizeDistance(product.dimensions, scannedSize) <= 0.5;
    return !fit || fitsSpot(product, scannedSize);
  });
  return ranked[i % Math.max(ranked.length, 1)];
}

// Only fields the existing row does not have yet.
function missingFields<T extends Record<string, unknown>>(existing: Record<string, unknown>, fields: T): Partial<T> {
  return Object.fromEntries(
    Object.entries(fields).filter(([k, v]) => v !== undefined && existing[k] === undefined),
  ) as Partial<T>;
}

// Add-only: inserts seeded users, sellers, products and rooms that are missing (matched by name or slug)
// and fills fields they lack. Nothing is ever deleted or overwritten, so rows the app created and seeded
// rows the app changed stay as they are. With a scan, 10 scan-built rooms (slug <room>-scan) are added
// beside the seeded ones. Run seed/upload.mjs afterwards to attach missing files.
export const run = internalMutation({
  args: { scan: v.optional(v.any()) },
  handler: async (ctx, { scan }) => {
    let added = 0;
    const existingUsers = await ctx.db.query("users").collect();
    const userIds: Id<"users">[] = [];
    for (const name of data.users) {
      let id = existingUsers.find((u) => u.name === name)?._id;
      if (!id) {
        id = await ctx.db.insert("users", { name });
        added++;
      }
      userIds.push(id);
      const collections = await ctx.db
        .query("collections")
        .withIndex("by_user", (q) => q.eq("userId", id))
        .collect();
      if (collections.length === 0) {
        await ctx.db.insert("collections", { userId: id, name: "Saved", roomIds: [], productIds: [] });
        added++;
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
      if (existing) {
        const patch = missingFields(existing, fields);
        if (Object.keys(patch).length) await ctx.db.patch(existing._id, patch);
        sellerIds.set(s.key, existing._id);
      } else {
        sellerIds.set(s.key, await ctx.db.insert("sellers", fields));
        added++;
      }
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
        vendorUrl: p.vendorUrl,
      };
      const existing = await ctx.db
        .query("products")
        .withIndex("by_slug", (q) => q.eq("slug", p.slug))
        .unique();
      if (existing) {
        const patch = missingFields(existing, fields);
        if (Object.keys(patch).length) await ctx.db.patch(existing._id, patch);
        products.push(existing);
      } else {
        products.push((await ctx.db.get(await ctx.db.insert("products", fields)))!);
        added++;
      }
    }

    const templates = [{ suffix: "", template: roomTemplate(undefined) }];
    const scanned = roomTemplate(scan);
    if (scanned.fromScan) templates.push({ suffix: "-scan", template: scanned });
    for (const { suffix, template } of templates) {
      for (const [i, r] of data.rooms.entries()) {
        const slug = r.slug + suffix;
        const existing = await ctx.db
          .query("rooms")
          .withIndex("by_slug", (q) => q.eq("slug", slug))
          .unique();
        if (existing) continue;
        await ctx.db.insert("rooms", {
          slug,
          ownerId: userIds[r.ownerIndex],
          title: suffix ? `${r.title} · real scan` : r.title,
          published: true,
          shell: template.shell,
          placements: template.placements.map(({ scannedSize, ...p }) => {
            const product = pick(products, p.category, scannedSize, i, true);
            return {
              ...p,
              ...(scannedSize ? { scannedSize } : {}),
              ...(product ? { productId: product._id as string } : {}),
            };
          }),
        });
        added++;
      }
    }

    return { source: scanned.fromScan ? "SampleRoom.json + scan" : "SampleRoom.json", added };
  },
});

// Corrects values an earlier seed wrote, and only while the row still carries them: the example.com
// vendorUrl, a product's previous seeded name, and a seeded room's product pick that the earlier rule
// made but that does not fit its spot. Anything the app or a person changed stays as it is.
export const correctSeeded = internalMutation({
  args: { scan: v.optional(v.any()) },
  handler: async (ctx, { scan }) => {
    const corrected: string[] = [];
    const products: Doc<"products">[] = [];
    for (const p of data.products) {
      const doc = await ctx.db
        .query("products")
        .withIndex("by_slug", (q) => q.eq("slug", p.slug))
        .unique();
      if (!doc) continue;
      const patch: Partial<Doc<"products">> = {};
      if (doc.vendorUrl === `https://example.com/p/${p.slug}`) patch.vendorUrl = p.vendorUrl;
      if (p.previousName && doc.name === p.previousName) patch.name = p.name;
      if (Object.keys(patch).length) {
        await ctx.db.patch(doc._id, patch);
        corrected.push(`${p.slug}: ${Object.keys(patch).join(", ")}`);
      }
      products.push(doc);
    }

    const templates = [{ suffix: "", template: roomTemplate(undefined) }];
    const scanned = roomTemplate(scan);
    if (scanned.fromScan) templates.push({ suffix: "-scan", template: scanned });
    for (const { suffix, template } of templates) {
      for (const [i, r] of data.rooms.entries()) {
        const room = await ctx.db
          .query("rooms")
          .withIndex("by_slug", (q) => q.eq("slug", r.slug + suffix))
          .unique();
        if (!room) continue;
        let changed = false;
        const placements = room.placements.map((placement) => {
          const seeded = template.placements.find((t) => t.id === placement.id);
          if (!seeded || placement.category !== seeded.category) return placement;
          const before = pick(products, seeded.category, seeded.scannedSize, i, false);
          if (!before || placement.productId !== before._id || fitsSpot(before, seeded.scannedSize)) return placement;
          const after = pick(products, seeded.category, seeded.scannedSize, i, true);
          if (!after) return placement;
          changed = true;
          corrected.push(`${room.slug}/${placement.id}: ${before.slug} → ${after.slug}`);
          return { ...placement, productId: after._id as string };
        });
        if (changed) await ctx.db.patch(room._id, { placements });
      }
    }
    return corrected;
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
    if (!doc || !url || (doc as Record<string, unknown>)[field]) return null;
    if (table === "rooms" && field !== "thumbnailUrl") return null;
    await ctx.db.patch(doc._id, { [field]: url });
    return url;
  },
});

// For each target, the URL its field holds and the sha256 (base64) of that file, or null when the field
// is empty or does not point at one of our files. The storage table is read once for all targets.
export const fileHashes = internalQuery({
  args: { targets: v.array(v.object(fileArgs)) },
  handler: async (ctx, { targets }) => {
    const hashes = new Map<string, string>();
    for (const file of await ctx.db.system.query("_storage").collect()) {
      const url = await ctx.storage.getUrl(file._id);
      if (url) hashes.set(url, file.sha256);
    }
    const out = [];
    for (const { table, slug, field } of targets) {
      const doc = await ctx.db
        .query(table)
        .withIndex("by_slug", (q) => q.eq("slug", slug))
        .unique();
      const url = doc && (doc as Record<string, unknown>)[field];
      out.push(typeof url === "string" ? { url, sha256: hashes.get(url) ?? null } : { url: null, sha256: null });
    }
    return out;
  },
});

// Replaces a seeded file only while the field still holds expectedUrl, the placeholder URL that
// seed:fileHashes matched by content hash; anything the app or a person set since is left alone. Nothing is deleted.
export const replacePlaceholder = internalMutation({
  args: { ...fileArgs, storageId: v.id("_storage"), expectedUrl: v.string() },
  handler: async (ctx, { table, slug, field, storageId, expectedUrl }) => {
    const doc = await ctx.db
      .query(table)
      .withIndex("by_slug", (q) => q.eq("slug", slug))
      .unique();
    const url = await ctx.storage.getUrl(storageId);
    if (!doc || !url || (doc as Record<string, unknown>)[field] !== expectedUrl) return null;
    await ctx.db.patch(doc._id, { [field]: url });
    return url;
  },
});

// Each seeded room's placements with the slug of the product placed there, so seed/render_thumbs.py
// renders the rooms as they are deployed.
export const roomPicks = internalQuery({
  args: {},
  handler: async (ctx) => {
    const slugs = new Map((await ctx.db.query("products").collect()).map((p) => [p._id as string, p.slug]));
    const rooms = [];
    for (const r of data.rooms) {
      for (const slug of [r.slug, `${r.slug}-scan`]) {
        const room = await ctx.db
          .query("rooms")
          .withIndex("by_slug", (q) => q.eq("slug", slug))
          .unique();
        if (!room) continue;
        rooms.push({
          slug,
          shell: room.shell,
          placements: room.placements.map((p) => ({ transform: p.transform, product: (p.productId && slugs.get(p.productId)) ?? null })),
        });
      }
    }
    return rooms;
  },
});

// Seeded rooms in the feed and how many lack a thumbnail, for the demo reset's checks.
export const status = internalQuery({
  args: {},
  handler: async (ctx) => {
    const seeded = (await ctx.db.query("rooms").collect()).filter((r) => r.slug);
    return { seededRooms: seeded.length, seededWithoutThumbnail: seeded.filter((r) => !r.thumbnailUrl).length };
  },
});

export const SMOKE_PREFIX = "smoke check:";

// Removes the design and order the demo reset's smoke checks just created, and nothing else: the design
// prompt must start with SMOKE_PREFIX and both must be under 10 minutes old, the order no older than the design.
export const deleteSmoke = internalMutation({
  args: { orderId: v.optional(v.id("orders")), designId: v.id("designs") },
  handler: async (ctx, { orderId, designId }) => {
    const recent = (t: number) => Date.now() - t < 10 * 60 * 1000;
    const design = await ctx.db.get(designId);
    if (!design || !design.prompt.startsWith(SMOKE_PREFIX) || !recent(design._creationTime)) return null;
    const order = orderId ? await ctx.db.get(orderId) : null;
    if (order && recent(order._creationTime) && order._creationTime >= design._creationTime) await ctx.db.delete(order._id);
    await ctx.db.delete(designId);
    return null;
  },
});
