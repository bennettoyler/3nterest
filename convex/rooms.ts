import { v } from "convex/values";
import { mutation, query } from "./_generated/server";
import { placement, roomShell } from "./schema";
import { toRoom } from "./lib/shape";

export const feed = query({
  args: {},
  handler: async (ctx) => {
    const rooms = await ctx.db
      .query("rooms")
      .withIndex("by_published", (q) => q.eq("published", true))
      .order("desc")
      .collect();
    return await Promise.all(rooms.map((r) => toRoom(ctx, r)));
  },
});

export const get = query({
  args: { id: v.id("rooms") },
  handler: async (ctx, { id }) => {
    const room = await ctx.db.get(id);
    if (!room) throw new Error(`Room ${id} not found`);
    return await toRoom(ctx, room);
  },
});

export const byOwner = query({
  args: { ownerId: v.id("users") },
  handler: async (ctx, { ownerId }) => {
    const rooms = await ctx.db
      .query("rooms")
      .withIndex("by_owner", (q) => q.eq("ownerId", ownerId))
      .order("desc")
      .collect();
    return await Promise.all(rooms.map((r) => toRoom(ctx, r)));
  },
});

export const save = mutation({
  args: {
    room: v.object({
      id: v.string(),
      ownerId: v.id("users"),
      ownerName: v.optional(v.string()),
      title: v.string(),
      thumbnailUrl: v.optional(v.string()),
      published: v.boolean(),
      shell: roomShell,
      placements: v.array(placement),
      remixedFromId: v.optional(v.string()),
    }),
  },
  handler: async (ctx, { room }) => {
    const fields = {
      ownerId: room.ownerId,
      title: room.title,
      published: room.published,
      shell: room.shell,
      placements: room.placements,
      ...(room.thumbnailUrl ? { thumbnailUrl: room.thumbnailUrl } : {}),
    };
    const existing = room.id ? ctx.db.normalizeId("rooms", room.id) : null;
    if (existing && (await ctx.db.get(existing))) {
      await ctx.db.patch(existing, fields);
      return existing;
    }
    const remixedFromId = room.remixedFromId ? ctx.db.normalizeId("rooms", room.remixedFromId) : null;
    return await ctx.db.insert("rooms", { ...fields, ...(remixedFromId ? { remixedFromId } : {}) });
  },
});

export const publish = mutation({
  args: { roomId: v.id("rooms"), title: v.string(), storageId: v.id("_storage") },
  handler: async (ctx, { roomId, title, storageId }) => {
    const thumbnailUrl = (await ctx.storage.getUrl(storageId)) ?? undefined;
    await ctx.db.patch(roomId, { title, published: true, thumbnailUrl });
    return null;
  },
});

export const remix = mutation({
  args: { roomId: v.id("rooms"), userId: v.id("users") },
  handler: async (ctx, { roomId, userId }) => {
    const source = await ctx.db.get(roomId);
    if (!source) throw new Error(`Room ${roomId} not found`);
    const id = await ctx.db.insert("rooms", {
      ownerId: userId,
      title: `${source.title} (remix)`,
      published: false,
      shell: source.shell,
      placements: source.placements,
      remixedFromId: source._id,
    });
    return await toRoom(ctx, (await ctx.db.get(id))!);
  },
});
