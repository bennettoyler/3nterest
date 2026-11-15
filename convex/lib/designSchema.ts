export type DesignPartBody = {
  name: string;
  shape: "box" | "cylinder";
  sizeCm: number[];
  positionCm: number[];
  rotationDeg: number[];
  material: string;
  colorHex: string;
};

export type CutItemBody = {
  part: string;
  material: string;
  lengthCm: number;
  widthCm: number;
  thicknessCm: number;
  quantity: number;
};

export type DesignBody = {
  title: string;
  parts: DesignPartBody[];
  cutList: CutItemBody[];
  hardware: string[];
  steps: string[];
};

const isRecord = (x: unknown): x is Record<string, unknown> => typeof x === "object" && x !== null && !Array.isArray(x);
const isVec3 = (x: unknown): x is number[] =>
  Array.isArray(x) && x.length === 3 && x.every((n) => typeof n === "number" && Number.isFinite(n));
const isFiniteNumber = (x: unknown): x is number => typeof x === "number" && Number.isFinite(x);
const strings = (x: unknown) => (Array.isArray(x) ? x.filter((s): s is string => typeof s === "string") : []);

export function parseDesign(raw: unknown): DesignBody | null {
  if (typeof raw === "string") {
    try {
      raw = JSON.parse(raw);
    } catch {
      return null;
    }
  }
  if (!isRecord(raw) || typeof raw.title !== "string" || !Array.isArray(raw.parts)) return null;
  if (raw.parts.length < 1 || raw.parts.length > 40) return null;

  const parts: DesignPartBody[] = [];
  for (const p of raw.parts) {
    if (!isRecord(p) || (p.shape !== "box" && p.shape !== "cylinder")) return null;
    if (!isVec3(p.sizeCm) || !isVec3(p.positionCm) || !isVec3(p.rotationDeg)) return null;
    parts.push({
      name: typeof p.name === "string" ? p.name : "part",
      shape: p.shape,
      sizeCm: p.sizeCm,
      positionCm: p.positionCm,
      rotationDeg: p.rotationDeg,
      material: typeof p.material === "string" ? p.material : "wood",
      colorHex: typeof p.colorHex === "string" && /^#[0-9a-fA-F]{6}$/.test(p.colorHex) ? p.colorHex : "#B08050",
    });
  }

  const cutList: CutItemBody[] = (Array.isArray(raw.cutList) ? raw.cutList : []).flatMap((c) =>
    isRecord(c) &&
    typeof c.part === "string" &&
    isFiniteNumber(c.lengthCm) &&
    isFiniteNumber(c.widthCm) &&
    isFiniteNumber(c.thicknessCm) &&
    isFiniteNumber(c.quantity)
      ? [
          {
            part: c.part,
            material: typeof c.material === "string" ? c.material : "wood",
            lengthCm: c.lengthCm,
            widthCm: c.widthCm,
            thicknessCm: c.thicknessCm,
            quantity: Math.max(1, Math.round(c.quantity)),
          },
        ]
      : [],
  );

  return { title: raw.title, parts, cutList, hardware: strings(raw.hardware), steps: strings(raw.steps) };
}
