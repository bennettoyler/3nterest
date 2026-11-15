import { v } from "convex/values";
import { action, internalMutation, mutation, query } from "./_generated/server";
import { internal } from "./_generated/api";
import { designBody } from "./schema";
import { cannedFor } from "./lib/cannedDesigns";
import { parseDesign, type DesignBody } from "./lib/designSchema";
import { toDesign, toProduct } from "./lib/shape";

const TIMEOUT_MS = 8000;

const SYSTEM_PROMPT = `You design furniture for a 3D room planner. Build the piece only from boxes and cylinders.
Coordinates: centimetres, origin at the centre of the floor footprint, Y up, the piece standing on y = 0.
positionCm is the centre of each part; sizeCm is [width, height, depth] for boxes and [diameter, height, diameter] for cylinders; rotationDeg is [x, y, z] in degrees.
Use realistic lumber sizes and joinery. Give each part a material and a #RRGGBB colour.
The cut list must be consistent with the parts (one row per distinct piece with its quantity), followed by the hardware list and numbered build steps without the numbers.
Keep it compact so it returns quickly: at most 16 parts, at most 8 cut list rows, at most 8 hardware items, and at most 7 short build steps.`;

const vec3 = { type: "array", items: { type: "number" } };
const jsonSchema = {
  type: "object",
  additionalProperties: false,
  required: ["title", "parts", "cutList", "hardware", "steps"],
  properties: {
    title: { type: "string" },
    parts: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "shape", "sizeCm", "positionCm", "rotationDeg", "material", "colorHex"],
        properties: {
          name: { type: "string" },
          shape: { type: "string", enum: ["box", "cylinder"] },
          sizeCm: vec3,
          positionCm: vec3,
          rotationDeg: vec3,
          material: { type: "string" },
          colorHex: { type: "string" },
        },
      },
    },
    cutList: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["part", "material", "lengthCm", "widthCm", "thicknessCm", "quantity"],
        properties: {
          part: { type: "string" },
          material: { type: "string" },
          lengthCm: { type: "number" },
          widthCm: { type: "number" },
          thicknessCm: { type: "number" },
          quantity: { type: "integer" },
        },
      },
    },
    hardware: { type: "array", items: { type: "string" } },
    steps: { type: "array", items: { type: "string" } },
  },
};

async function askOpenAI(prompt: string): Promise<DesignBody | null> {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
  try {
    const res = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      signal: controller.signal,
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL ?? "gpt-4o-mini",
        messages: [
          { role: "system", content: SYSTEM_PROMPT },
          { role: "user", content: prompt },
        ],
        max_tokens: 2500,
        response_format: { type: "json_schema", json_schema: { name: "design", strict: true, schema: jsonSchema } },
      }),
    });
    if (!res.ok) {
      console.warn(`OpenAI returned ${res.status}`);
      return null;
    }
    const body = await res.json();
    return parseDesign(body?.choices?.[0]?.message?.content);
  } catch (error) {
    console.warn("OpenAI call failed, using canned design:", String(error));
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export const generate = action({
  args: { prompt: v.string(), userId: v.id("users") },
  handler: async (ctx, { prompt, userId }): Promise<ReturnType<typeof toDesign>> => {
    const design = (await askOpenAI(prompt)) ?? cannedFor(prompt);
    return await ctx.runMutation(internal.designs.store, { ownerId: userId, prompt, ...design });
  },
});

export const store = internalMutation({
  args: { ownerId: v.id("users"), prompt: v.string(), ...designBody },
  handler: async (ctx, args) => toDesign((await ctx.db.get(await ctx.db.insert("designs", args)))!),
});

export const byIds = query({
  args: { ids: v.array(v.string()) },
  handler: async (ctx, { ids }) => {
    const designs = [];
    for (const raw of ids) {
      const id = ctx.db.normalizeId("designs", raw);
      const design = id ? await ctx.db.get(id) : null;
      if (design) designs.push(toDesign(design));
    }
    return designs;
  },
});

export const listForSale = mutation({
  args: { designId: v.string(), priceCents: v.number() },
  handler: async (ctx, args) => {
    const designId = ctx.db.normalizeId("designs", args.designId);
    const design = designId ? await ctx.db.get(designId) : null;
    if (!designId || !design) throw new Error(`Design ${args.designId} was never saved to Convex (offline fallback); generate it again to list it`);
    const { priceCents } = args;
    const owner = await ctx.db.get(design.ownerId);
    const existing = await ctx.db
      .query("sellers")
      .withIndex("by_user", (q) => q.eq("userId", design.ownerId))
      .first();
    const sellerId =
      existing?._id ??
      (await ctx.db.insert("sellers", { name: owner?.name ?? "Maker", kind: "creator", userId: design.ownerId }));

    const extent = (axis: number) => {
      const lo = Math.min(...design.parts.map((p) => p.positionCm[axis] - p.sizeCm[axis] / 2));
      const hi = Math.max(...design.parts.map((p) => p.positionCm[axis] + p.sizeCm[axis] / 2));
      return Math.max(0.01, (hi - lo) / 100);
    };
    const productId = await ctx.db.insert("products", {
      sellerId,
      name: design.title,
      category: "other",
      priceCents: Math.round(priceCents),
      dimensions: { width: extent(0), depth: extent(2), height: extent(1) },
      designId,
    });
    return await toProduct(ctx, (await ctx.db.get(productId))!);
  },
});
