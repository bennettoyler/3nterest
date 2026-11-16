import type { Box, Item, Room } from "./IsoRoom";

type Along = "x" | "z";

function place(x: number, z: number, along: Along, local: Box[]): Box[] {
  return local.map((b) =>
    along === "x"
      ? { ...b, x: x + b.x, z: z + b.z }
      : { ...b, x: x + b.z, z: z + b.x, w: b.d, d: b.w },
  );
}

const sofa = (x: number, z: number, len: number, c: string, cushion: string, along: Along = "x"): Item => ({
  boxes: place(x, z, along, [
    { x: 0, z: 0, w: len, d: 0.24, h: 0.82, c },
    { x: 0, z: 0.24, w: 0.2, d: 0.66, h: 0.58, c },
    { x: 0.2, z: 0.24, w: len - 0.4, d: 0.66, h: 0.3, c },
    { x: 0.2, z: 0.24, w: len - 0.4, d: 0.66, y: 0.3, h: 0.12, c: cushion },
    { x: len - 0.2, z: 0.24, w: 0.2, d: 0.66, h: 0.58, c },
  ]),
});

const table = (x: number, z: number, w: number, d: number, h: number, c: string): Item => {
  const t = 0.07;
  const leg = (lx: number, lz: number): Box => ({ x: lx, z: lz, w: t, d: t, h: h - t, c });
  return {
    boxes: [
      leg(x, z),
      leg(x + w - t, z),
      leg(x, z + d - t),
      leg(x + w - t, z + d - t),
      { x, z, w, d, y: h - t, h: t, c },
    ],
  };
};

const block = (x: number, z: number, w: number, d: number, h: number, c: string): Item => ({
  boxes: [{ x, z, w, d, h, c }],
});

const chair = (x: number, z: number, c: string, along: Along = "x"): Item => ({
  boxes: place(x, z, along, [
    { x: 0, z: 0, w: 0.55, d: 0.12, h: 0.9, c },
    { x: 0, z: 0.12, w: 0.55, d: 0.48, h: 0.42, c },
  ]),
});

const tv = (x: number, z: number, w: number, c: string, along: Along = "x"): Item => ({
  boxes: place(x, z, along, [
    { x: 0, z: 0, w, d: 0.42, h: 0.45, c },
    { x: 0.12, z: 0.1, w: w - 0.24, d: 0.06, y: 0.45, h: 0.72, c: "#1B1612" },
  ]),
});

const bed = (x: number, z: number, w: number, d: number, frame: string, blanket: string): Item => ({
  boxes: [
    { x, z, w, d: 0.1, h: 1, c: frame },
    { x, z: z + 0.1, w, d: d - 0.1, h: 0.28, c: frame },
    { x: x + 0.04, z: z + 0.1, w: w - 0.08, d: d - 0.14, y: 0.28, h: 0.2, c: "#FFFFFF" },
    { x: x + 0.14, z: z + 0.18, w: w / 2 - 0.2, d: 0.4, y: 0.48, h: 0.1, c: "#F4EEE7" },
    { x: x + w / 2 + 0.06, z: z + 0.18, w: w / 2 - 0.2, d: 0.4, y: 0.48, h: 0.1, c: "#F4EEE7" },
    { x: x + 0.02, z: z + d * 0.45, w: w - 0.04, d: d * 0.55 - 0.02, y: 0.28, h: 0.23, c: blanket },
  ],
});

const lamp = (x: number, z: number, c = "#FFF1E0"): Item => ({
  boxes: [
    { x: x - 0.14, z: z - 0.14, w: 0.28, d: 0.28, h: 0.05, c: "#3A302A" },
    { x: x - 0.03, z: z - 0.03, w: 0.06, d: 0.06, h: 1.3, c: "#3A302A" },
    { x: x - 0.18, z: z - 0.18, w: 0.36, d: 0.36, y: 1.3, h: 0.32, c },
  ],
});

const plant = (x: number, z: number): Item => ({
  boxes: [
    { x, z, w: 0.34, d: 0.34, h: 0.36, c: "#D98A5B" },
    { x: x - 0.1, z: z - 0.1, w: 0.54, d: 0.54, y: 0.36, h: 0.6, c: "#6F8F66" },
  ],
});

const WOOD = "#C99A68";
const WALNUT = "#8A5F41";
const LINEN = "#F3EEE7";
const ORANGE = "#FF6600";

const heroItems = {
  sofa: sofa(1.25, 0.2, 2.1, "#E9E1D6", "#FFFFFF"),
  coffee: table(1.75, 1.75, 1.1, 0.6, 0.45, WOOD),
  shelf: block(0.12, 1.3, 0.36, 0.9, 1.8, WALNUT),
  chair: chair(0.5, 3.0, ORANGE, "z"),
  lamp: lamp(0.6, 0.55),
  plant: plant(4.3, 0.35),
  tv: tv(3.3, 3.1, 1.4, WALNUT),
};

const shell = {
  w: 5,
  d: 4.2,
  h: 2.5,
  wallL: "#F4E8DB",
  wallR: "#FBF3EA",
  floor: "#E6D3BE",
};

export const heroRoom: Room = {
  ...shell,
  window: { x: 1.55, w: 1.5, y: 1.15, h: 0.95 },
  rug: { x: 1.2, z: 1.3, w: 2.4, d: 1.6, c: "#F7EBDD" },
  items: [
    {
      ...heroItems.sofa,
      selected: true,
      drift: true,
      tag: { title: "Linnea 3-Seat Sofa", sub: "Nordhem · $649" },
    },
    heroItems.coffee,
    heroItems.shelf,
    heroItems.chair,
    heroItems.lamp,
    heroItems.plant,
  ],
};

export type FeedRoom = { title: string; by: string; room: Room };

export const feedRooms: FeedRoom[] = [
  {
    title: "Sunlit Living Room",
    by: "Maya",
    room: {
      ...shell,
      w: 4.4,
      d: 3.8,
      h: 2.9,
      window: { x: 1.3, w: 1.7, y: 1.2, h: 1.2 },
      rug: { x: 1, z: 1.2, w: 2.4, d: 1.5, c: "#FFD9BC" },
      items: [
        sofa(1.1, 0.2, 2.1, "#E9E1D6", "#FFFFFF"),
        table(1.6, 1.6, 1.1, 0.6, 0.45, WOOD),
        chair(0.4, 2.4, ORANGE, "z"),
        lamp(0.55, 0.55),
        plant(3.7, 0.35),
        block(0.12, 1.2, 0.36, 0.8, 1.5, WALNUT),
      ],
    },
  },
  {
    title: "Movie Night Den",
    by: "Jon",
    room: {
      w: 4,
      d: 3.6,
      h: 2,
      wallL: "#3A302A",
      wallR: "#463A33",
      floor: "#2B2420",
      rug: { x: 0.9, z: 1, w: 2.4, d: 1.8, c: "#FF6600" },
      items: [
        sofa(0.2, 0.9, 2.1, "#6B5A4E", "#8A7663", "z"),
        tv(1.3, 0.15, 1.6, WALNUT),
        table(1.5, 1.6, 1, 0.6, 0.4, "#D9C7B2"),
        lamp(3.5, 0.5, ORANGE),
      ],
    },
  },
  {
    title: "Weekend Guest Room",
    by: "Maya",
    room: {
      w: 4,
      d: 3.6,
      h: 2.2,
      wallL: "#FFD3B0",
      wallR: "#FFE2CB",
      floor: "#FFF6EE",
      window: { x: 2.7, w: 0.9, y: 1, h: 0.9 },
      items: [
        bed(0.9, 0.15, 1.6, 2.1, WOOD, ORANGE),
        block(0.3, 0.2, 0.45, 0.4, 0.5, WOOD),
        lamp(3.4, 0.5, "#FFFFFF"),
        block(2.9, 2.6, 0.9, 0.45, 0.8, WALNUT),
      ],
    },
  },
  {
    title: "Scandi Lounge",
    by: "Elsa",
    room: {
      w: 4.6,
      d: 3.4,
      h: 2.1,
      wallL: "#EFEAE3",
      wallR: "#F7F3EE",
      floor: "#DCC9B2",
      rug: { x: 1.2, z: 1.1, w: 2.4, d: 1.5, c: "#FFFFFF" },
      items: [
        sofa(1.3, 0.2, 2.1, "#C9B8A5", LINEN),
        table(1.9, 1.5, 0.9, 0.6, 0.45, "#FFFFFF"),
        chair(0.4, 1.9, "#E9E1D6", "z"),
        block(3.7, 0.15, 0.77, 0.39, 1.47, "#FFFFFF"),
        plant(0.45, 0.4),
      ],
    },
  },
];
