import type { Doc } from "../_generated/dataModel";
import type { QueryCtx } from "../_generated/server";

export function toUser(u: Doc<"users">) {
  return { id: u._id as string, name: u.name, avatarUrl: u.avatarUrl };
}

export function toSeller(s: Doc<"sellers">) {
  return { id: s._id as string, name: s.name, kind: s.kind, logoUrl: s.logoUrl };
}

export async function toRoom(ctx: QueryCtx, r: Doc<"rooms">) {
  const owner = await ctx.db.get(r.ownerId);
  return {
    id: r._id as string,
    ownerId: r.ownerId as string,
    ownerName: owner?.name ?? "Unknown",
    title: r.title,
    thumbnailUrl: r.thumbnailUrl,
    published: r.published,
    shell: r.shell,
    placements: r.placements,
    remixedFromId: r.remixedFromId as string | undefined,
  };
}

export async function toProduct(ctx: QueryCtx, p: Doc<"products">) {
  const seller = await ctx.db.get(p.sellerId);
  return {
    id: p._id as string,
    sellerId: p.sellerId as string,
    sellerName: seller?.name ?? "Unknown",
    name: p.name,
    category: p.category,
    priceCents: p.priceCents,
    dimensions: p.dimensions,
    modelUrl: p.modelUrl,
    thumbnailUrl: p.thumbnailUrl,
    instructionsUrl: p.instructionsUrl,
    vendorUrl: p.vendorUrl,
    designId: p.designId as string | undefined,
  };
}

export function toDesign(d: Doc<"designs">) {
  return {
    id: d._id as string,
    ownerId: d.ownerId as string,
    prompt: d.prompt,
    title: d.title,
    parts: d.parts,
    cutList: d.cutList,
    hardware: d.hardware,
    steps: d.steps,
  };
}

export function toOrder(o: Doc<"orders">) {
  return {
    id: o._id as string,
    productId: o.productId as string,
    productName: o.productName,
    sellerId: o.sellerId as string,
    sellerName: o.sellerName,
    amountCents: o.amountCents,
    platformFeeCents: o.platformFeeCents,
    sellerCents: o.sellerCents,
    status: o.status,
  };
}

export function toCollection(c: Doc<"collections">) {
  return { id: c._id as string, name: c.name, roomIds: c.roomIds, productIds: c.productIds };
}
