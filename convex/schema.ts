import { defineSchema, defineTable } from "convex/server";
import { v } from "convex/values";

export const category = v.union(
  v.literal("chair"),
  v.literal("table"),
  v.literal("sofa"),
  v.literal("bed"),
  v.literal("storage"),
  v.literal("television"),
  v.literal("other"),
);

export const dimensions = v.object({ width: v.number(), depth: v.number(), height: v.number() });

export const surface = v.object({ transform: v.array(v.number()), width: v.number(), height: v.number() });

export const roomShell = v.object({ walls: v.array(surface), doors: v.array(surface), windows: v.array(surface) });

export const placement = v.object({
  id: v.string(),
  transform: v.array(v.number()),
  productId: v.optional(v.string()),
  designId: v.optional(v.string()),
  category,
  scannedSize: v.optional(dimensions),
});

export const designPart = v.object({
  name: v.string(),
  shape: v.union(v.literal("box"), v.literal("cylinder")),
  sizeCm: v.array(v.number()),
  positionCm: v.array(v.number()),
  rotationDeg: v.array(v.number()),
  material: v.string(),
  colorHex: v.string(),
});

export const cutItem = v.object({
  part: v.string(),
  material: v.string(),
  lengthCm: v.number(),
  widthCm: v.number(),
  thicknessCm: v.number(),
  quantity: v.number(),
});

export const designBody = {
  title: v.string(),
  parts: v.array(designPart),
  cutList: v.array(cutItem),
  hardware: v.array(v.string()),
  steps: v.array(v.string()),
};

export default defineSchema({
  users: defineTable({
    name: v.string(),
    avatarUrl: v.optional(v.string()),
  }),
  sellers: defineTable({
    name: v.string(),
    kind: v.string(),
    logoUrl: v.optional(v.string()),
    userId: v.optional(v.id("users")),
    whopAccountId: v.optional(v.string()),
  }).index("by_user", ["userId"]),
  products: defineTable({
    slug: v.optional(v.string()),
    sellerId: v.id("sellers"),
    name: v.string(),
    category,
    priceCents: v.number(),
    dimensions,
    modelUrl: v.optional(v.string()),
    thumbnailUrl: v.optional(v.string()),
    instructionsUrl: v.optional(v.string()),
    vendorUrl: v.optional(v.string()),
    designId: v.optional(v.id("designs")),
    checkoutUrl: v.optional(v.string()),
  }).index("by_slug", ["slug"]),
  rooms: defineTable({
    slug: v.optional(v.string()),
    ownerId: v.id("users"),
    title: v.string(),
    thumbnailUrl: v.optional(v.string()),
    published: v.boolean(),
    shell: roomShell,
    placements: v.array(placement),
    remixedFromId: v.optional(v.id("rooms")),
  })
    .index("by_owner", ["ownerId"])
    .index("by_published", ["published"])
    .index("by_slug", ["slug"]),
  designs: defineTable({
    ownerId: v.id("users"),
    prompt: v.string(),
    ...designBody,
  }),
  collections: defineTable({
    userId: v.id("users"),
    name: v.string(),
    roomIds: v.array(v.string()),
    productIds: v.array(v.string()),
  }).index("by_user", ["userId"]),
  orders: defineTable({
    productId: v.id("products"),
    productName: v.string(),
    sellerId: v.id("sellers"),
    sellerName: v.string(),
    buyerId: v.id("users"),
    amountCents: v.number(),
    platformFeeCents: v.number(),
    sellerCents: v.number(),
    status: v.union(v.literal("pending"), v.literal("paid")),
  }).index("by_seller_status", ["sellerId", "status"]),
});
