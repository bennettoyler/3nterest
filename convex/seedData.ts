import type { Doc } from "./_generated/dataModel";

type Category = Doc<"products">["category"];

export const users = ["Maya Chen", "Jonas Weber", "Priya Nair", "Sam Okafor"];

export const sellers: { key: string; name: string; kind: string; userIndex?: number }[] = [
  { key: "nordhem", name: "Nordhem", kind: "brand" },
  { key: "parcel", name: "Parcel Home", kind: "brand" },
  { key: "maya", name: "Maya Chen Woodworks", kind: "creator", userIndex: 0 },
  { key: "oakiron", name: "Oak & Iron Studio", kind: "creator" },
  { key: "clayloft", name: "Clay Loft", kind: "creator" },
];

export const products: {
  slug: string;
  seller: string;
  name: string;
  category: Category;
  priceCents: number;
  size: [number, number, number];
}[] = [
  { slug: "harbor-lounge-chair", seller: "parcel", name: "Harbor Lounge Chair", category: "chair", priceCents: 18900, size: [0.7, 0.7, 0.85] },
  { slug: "walnut-dining-chair", seller: "maya", name: "Walnut Dining Chair", category: "chair", priceCents: 14900, size: [0.45, 0.5, 0.9] },
  { slug: "strand-desk-chair", seller: "nordhem", name: "Strand Desk Chair", category: "chair", priceCents: 7900, size: [0.55, 0.55, 0.95] },
  { slug: "iron-cafe-chair", seller: "oakiron", name: "Iron Café Chair", category: "chair", priceCents: 12500, size: [0.45, 0.5, 0.85] },
  { slug: "birk-coffee-table", seller: "nordhem", name: "Birk Coffee Table", category: "table", priceCents: 12900, size: [1.1, 0.6, 0.45] },
  { slug: "live-edge-dining-table", seller: "oakiron", name: "Live Edge Dining Table", category: "table", priceCents: 89000, size: [1.8, 0.9, 0.75] },
  { slug: "round-side-table", seller: "clayloft", name: "Round Side Table", category: "table", priceCents: 6900, size: [0.45, 0.45, 0.55] },
  { slug: "linnea-3-seat-sofa", seller: "nordhem", name: "Linnea 3-Seat Sofa", category: "sofa", priceCents: 64900, size: [2.0, 0.9, 0.8] },
  { slug: "cloud-sectional-sofa", seller: "parcel", name: "Cloud Sectional Sofa", category: "sofa", priceCents: 119900, size: [2.6, 1.6, 0.8] },
  { slug: "stack-bookcase", seller: "parcel", name: "Stack Bookcase", category: "storage", priceCents: 9900, size: [0.8, 0.3, 1.8] },
  { slug: "kallo-shelf-unit", seller: "nordhem", name: "Kallo Shelf Unit", category: "storage", priceCents: 8900, size: [0.77, 0.39, 1.47] },
  { slug: "walnut-sideboard", seller: "maya", name: "Walnut Sideboard", category: "storage", priceCents: 79000, size: [1.6, 0.45, 0.75] },
  { slug: "vista-55-tv", seller: "parcel", name: "Vista 55-inch TV with Stand", category: "television", priceCents: 49900, size: [1.4, 0.4, 1.1] },
  { slug: "orbit-65-tv", seller: "parcel", name: "Orbit 65-inch TV on Console", category: "television", priceCents: 89900, size: [1.6, 0.45, 1.3] },
  { slug: "fjell-queen-bed", seller: "nordhem", name: "Fjell Queen Bed", category: "bed", priceCents: 39900, size: [1.6, 2.1, 0.9] },
  { slug: "oak-step-stool", seller: "maya", name: "Oak Step Stool", category: "other", priceCents: 5900, size: [0.4, 0.35, 0.45] },
  { slug: "ceramic-floor-lamp", seller: "clayloft", name: "Ceramic Floor Lamp", category: "other", priceCents: 15900, size: [0.4, 0.4, 1.6] },
  { slug: "rattan-armchair", seller: "clayloft", name: "Rattan Armchair", category: "chair", priceCents: 22900, size: [0.75, 0.75, 0.8] },
];

export const rooms: { slug: string; title: string; ownerIndex: number; picks: Partial<Record<Category, string>> }[] = [
  { slug: "sunlit-living-room", title: "Sunlit Living Room", ownerIndex: 0, picks: { sofa: "linnea-3-seat-sofa", table: "birk-coffee-table", chair: "harbor-lounge-chair", television: "vista-55-tv" } },
  { slug: "cozy-reading-corner", title: "Cozy Reading Corner", ownerIndex: 1, picks: { sofa: "linnea-3-seat-sofa", table: "round-side-table", chair: "rattan-armchair", television: "vista-55-tv" } },
  { slug: "minimal-studio", title: "Minimal Studio", ownerIndex: 2, picks: { sofa: "linnea-3-seat-sofa", table: "birk-coffee-table", chair: "strand-desk-chair", television: "orbit-65-tv" } },
  { slug: "scandi-lounge", title: "Scandi Lounge", ownerIndex: 3, picks: { sofa: "cloud-sectional-sofa", table: "birk-coffee-table", chair: "walnut-dining-chair", television: "vista-55-tv" } },
  { slug: "movie-night-den", title: "Movie Night Den", ownerIndex: 0, picks: { sofa: "cloud-sectional-sofa", table: "round-side-table", chair: "harbor-lounge-chair", television: "orbit-65-tv" } },
  { slug: "warm-walnut-living", title: "Warm Walnut Living", ownerIndex: 1, picks: { sofa: "linnea-3-seat-sofa", table: "live-edge-dining-table", chair: "walnut-dining-chair", television: "vista-55-tv" } },
  { slug: "industrial-loft", title: "Industrial Loft", ownerIndex: 2, picks: { sofa: "cloud-sectional-sofa", table: "live-edge-dining-table", chair: "iron-cafe-chair", television: "orbit-65-tv" } },
  { slug: "clay-and-cane", title: "Clay and Cane", ownerIndex: 3, picks: { sofa: "linnea-3-seat-sofa", table: "round-side-table", chair: "rattan-armchair", television: "vista-55-tv" } },
];
