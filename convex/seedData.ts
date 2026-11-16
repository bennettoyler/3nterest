import type { Doc } from "./_generated/dataModel";

type Category = Doc<"products">["category"];

export const users = ["Maya Chen", "Jonas Weber", "Priya Nair", "Sam Okafor"];

// whopAccountId: sub-accounts under the Whop sandbox platform account biz_vCOXH8enY1QolG. They exist only in
// the sandbox, so the deployment must set WHOP_API_BASE=https://sandbox-api.whop.com/api/v1 (payments.ts
// defaults to production).
export const sellers: { key: string; name: string; kind: string; userIndex?: number; whopAccountId: string }[] = [
  { key: "nordhem", name: "Nordhem", kind: "brand", whopAccountId: "biz_YkK9KvOSUDDpqa" },
  { key: "parcel", name: "Parcel Home", kind: "brand", whopAccountId: "biz_MndMZtFHBUnYAD" },
  { key: "maya", name: "Maya Chen Woodworks", kind: "creator", userIndex: 0, whopAccountId: "biz_4TwpVkg5jsCGsd" },
  { key: "oakiron", name: "Oak & Iron Studio", kind: "creator", whopAccountId: "biz_ZBhHDQXYiURYrb" },
  { key: "clayloft", name: "Clay Loft", kind: "creator", whopAccountId: "biz_qU5oBxnADjQBBQ" },
];

// vendorUrl: a retailer page for a similar item. previousName: the name an earlier seed wrote, which
// seed:correctSeeded may replace while the row still carries it.
export const products: {
  slug: string;
  seller: string;
  name: string;
  previousName?: string;
  category: Category;
  priceCents: number;
  size: [number, number, number];
  vendorUrl: string;
}[] = [
  { slug: "harbor-lounge-chair", seller: "parcel", name: "Harbor Lounge Chair", category: "chair", priceCents: 18900, size: [0.7, 0.7, 0.85], vendorUrl: "https://www.ikea.com/us/en/cat/armchairs-chaises-fu006/" },
  { slug: "walnut-dining-chair", seller: "maya", name: "Walnut Dining Chair", category: "chair", priceCents: 14900, size: [0.45, 0.5, 0.9], vendorUrl: "https://www.ikea.com/us/en/cat/dining-chairs-25219/" },
  { slug: "strand-desk-chair", seller: "nordhem", name: "Strand Monobloc Chair", previousName: "Strand Desk Chair", category: "chair", priceCents: 7900, size: [0.55, 0.55, 0.95], vendorUrl: "https://www.ikea.com/us/en/search/?q=plastic%20chair" },
  { slug: "iron-cafe-chair", seller: "oakiron", name: "Painted Wooden Chair", previousName: "Iron Café Chair", category: "chair", priceCents: 12500, size: [0.45, 0.5, 0.85], vendorUrl: "https://www.ikea.com/us/en/search/?q=wooden%20chair" },
  { slug: "birk-coffee-table", seller: "nordhem", name: "Birk Coffee Table", category: "table", priceCents: 12900, size: [1.1, 0.6, 0.45], vendorUrl: "https://www.ikea.com/us/en/cat/accent-tables-10705/" },
  { slug: "live-edge-dining-table", seller: "oakiron", name: "Live Edge Dining Table", category: "table", priceCents: 89000, size: [1.8, 0.9, 0.75], vendorUrl: "https://www.ikea.com/us/en/cat/dining-tables-21825/" },
  { slug: "round-side-table", seller: "clayloft", name: "Round Side Table", category: "table", priceCents: 6900, size: [0.45, 0.45, 0.55], vendorUrl: "https://www.ikea.com/us/en/search/?q=round%20side%20table" },
  { slug: "linnea-3-seat-sofa", seller: "nordhem", name: "Linnea 3-Seat Sofa", category: "sofa", priceCents: 64900, size: [2.0, 0.9, 0.8], vendorUrl: "https://www.ikea.com/us/en/cat/sofas-sectionals-fu003/" },
  { slug: "cloud-sectional-sofa", seller: "parcel", name: "Cloud Sectional Sofa", category: "sofa", priceCents: 119900, size: [2.6, 1.6, 0.8], vendorUrl: "https://www.ikea.com/us/en/cat/fabric-sectionals-10671/" },
  { slug: "stack-bookcase", seller: "parcel", name: "Stack Bookcase", category: "storage", priceCents: 9900, size: [0.8, 0.3, 1.8], vendorUrl: "https://www.ikea.com/us/en/cat/bookcases-10382/" },
  { slug: "kallo-shelf-unit", seller: "nordhem", name: "Kallo Shelf Unit", category: "storage", priceCents: 8900, size: [0.77, 0.39, 1.47], vendorUrl: "https://www.ikea.com/us/en/cat/kallax-shelving-units-58285/" },
  { slug: "walnut-sideboard", seller: "maya", name: "Walnut Sideboard", category: "storage", priceCents: 79000, size: [1.6, 0.45, 0.75], vendorUrl: "https://www.ikea.com/us/en/cat/sideboards-buffets-sofa-tables-30454/" },
  { slug: "vista-55-tv", seller: "parcel", name: "Vista 55-inch TV with Stand", category: "television", priceCents: 49900, size: [1.4, 0.4, 1.1], vendorUrl: "https://www.amazon.com/s?k=55+inch+tv" },
  { slug: "orbit-65-tv", seller: "parcel", name: "Orbit 65-inch TV on Console", category: "television", priceCents: 89900, size: [1.6, 0.45, 1.3], vendorUrl: "https://www.amazon.com/s?k=65+inch+tv" },
  { slug: "fjell-queen-bed", seller: "nordhem", name: "Fjell Queen Bed", category: "bed", priceCents: 39900, size: [1.6, 2.1, 0.9], vendorUrl: "https://www.ikea.com/us/en/cat/beds-bm003/" },
  { slug: "oak-step-stool", seller: "maya", name: "Oak Step Stool", category: "other", priceCents: 5900, size: [0.4, 0.35, 0.45], vendorUrl: "https://www.ikea.com/us/en/cat/step-stools-step-ladders-20611/" },
  { slug: "ceramic-floor-lamp", seller: "clayloft", name: "Ceramic Floor Lamp", category: "other", priceCents: 15900, size: [0.4, 0.4, 1.6], vendorUrl: "https://www.ikea.com/us/en/cat/floor-lamps-10731/" },
  { slug: "rattan-armchair", seller: "clayloft", name: "Rocking Armchair", previousName: "Rattan Armchair", category: "chair", priceCents: 22900, size: [0.75, 0.75, 0.8], vendorUrl: "https://www.ikea.com/us/en/search/?q=rocking%20chair" },
  { slug: "vik-white-stacking-chair", seller: "nordhem", name: "Vik White Stacking Chair", category: "chair", priceCents: 4900, size: [0.48, 0.52, 0.85], vendorUrl: "https://www.ikea.com/us/en/search/?q=stacking%20chair" },
  { slug: "aero-mesh-task-chair", seller: "parcel", name: "Aero Mesh Task Chair", category: "chair", priceCents: 32900, size: [0.62, 0.66, 1.1], vendorUrl: "https://www.ikea.com/us/en/cat/office-chairs-20652/" },
  { slug: "flip-top-rolling-table", seller: "nordhem", name: "Flip-Top Rolling Table", category: "table", priceCents: 27900, size: [1.6, 0.8, 0.75], vendorUrl: "https://www.ikea.com/us/en/search/?q=conference%20table" },
  { slug: "rattan-cane-sideboard", seller: "maya", name: "Rattan Cane Sideboard", category: "storage", priceCents: 54900, size: [1.6, 0.45, 0.85], vendorUrl: "https://www.ikea.com/us/en/cat/sideboards-buffets-sofa-tables-30454/" },
  { slug: "lumen-75-wall-tv", seller: "parcel", name: "Lumen 75-inch Wall TV", category: "television", priceCents: 109900, size: [1.85, 0.08, 1.0], vendorUrl: "https://www.amazon.com/s?k=75+inch+tv" },
  { slug: "oak-writing-desk", seller: "maya", name: "Oak Writing Desk", category: "table", priceCents: 24900, size: [1.4, 0.7, 0.75], vendorUrl: "https://www.ikea.com/us/en/search/?q=writing%20desk" },
  { slug: "slim-filing-cabinet", seller: "nordhem", name: "Slim Filing Cabinet", category: "storage", priceCents: 12900, size: [0.45, 0.6, 1.1], vendorUrl: "https://www.ikea.com/us/en/search/?q=filing%20cabinet" },
  { slug: "open-oak-bookshelf", seller: "maya", name: "Open Oak Bookshelf", category: "storage", priceCents: 17900, size: [0.9, 0.32, 1.9], vendorUrl: "https://www.ikea.com/us/en/search/?q=bookshelf" },
  { slug: "mobile-whiteboard", seller: "nordhem", name: "Mobile Whiteboard", category: "other", priceCents: 21900, size: [1.5, 0.5, 1.9], vendorUrl: "https://www.ikea.com/us/en/search/?q=whiteboard" },
  { slug: "round-meeting-table", seller: "nordhem", name: "Round Meeting Table", category: "table", priceCents: 31900, size: [1.2, 1.2, 0.75], vendorUrl: "https://www.ikea.com/us/en/search/?q=round%20table" },
  { slug: "walnut-conference-table", seller: "maya", name: "Walnut Conference Table", category: "table", priceCents: 129900, size: [2.4, 1.1, 0.75], vendorUrl: "https://www.ikea.com/us/en/search/?q=conference%20table" },
  { slug: "frost-refrigerator", seller: "parcel", name: "Frost Refrigerator", category: "other", priceCents: 119900, size: [0.75, 0.72, 1.8], vendorUrl: "https://www.ikea.com/us/en/search/?q=refrigerator" },
  { slug: "gas-range-stove", seller: "parcel", name: "Gas Range Stove", category: "other", priceCents: 84900, size: [0.76, 0.66, 0.92], vendorUrl: "https://www.ikea.com/us/en/search/?q=stove" },
  { slug: "kitchen-sink-cabinet", seller: "nordhem", name: "Kitchen Sink Cabinet", category: "other", priceCents: 45900, size: [0.8, 0.6, 0.9], vendorUrl: "https://www.ikea.com/us/en/search/?q=kitchen%20sink" },
  { slug: "quiet-dishwasher", seller: "parcel", name: "Quiet Dishwasher", category: "other", priceCents: 64900, size: [0.6, 0.6, 0.85], vendorUrl: "https://www.ikea.com/us/en/search/?q=dishwasher" },
  { slug: "front-load-washer", seller: "parcel", name: "Front-Load Washer", category: "other", priceCents: 79900, size: [0.6, 0.62, 0.85], vendorUrl: "https://www.ikea.com/us/en/search/?q=washing%20machine" },
  { slug: "classic-toilet", seller: "nordhem", name: "Classic Toilet", category: "other", priceCents: 28900, size: [0.4, 0.7, 0.78], vendorUrl: "https://www.ikea.com/us/en/search/?q=toilet" },
  { slug: "soaking-bathtub", seller: "nordhem", name: "Soaking Bathtub", category: "other", priceCents: 99900, size: [1.7, 0.76, 0.56], vendorUrl: "https://www.ikea.com/us/en/search/?q=bathtub" },
  { slug: "oak-twin-bed", seller: "maya", name: "Oak Twin Bed", category: "bed", priceCents: 34900, size: [1.0, 2.0, 0.9], vendorUrl: "https://www.ikea.com/us/en/search/?q=twin%20bed" },
  { slug: "haven-king-bed", seller: "nordhem", name: "Haven King Bed", category: "bed", priceCents: 109900, size: [1.95, 2.05, 1.0], vendorUrl: "https://www.ikea.com/us/en/search/?q=king%20bed" },
  { slug: "oak-nightstand", seller: "maya", name: "Oak Nightstand", category: "storage", priceCents: 11900, size: [0.5, 0.4, 0.55], vendorUrl: "https://www.ikea.com/us/en/search/?q=nightstand" },
  { slug: "six-drawer-dresser", seller: "nordhem", name: "Six-Drawer Dresser", category: "storage", priceCents: 39900, size: [1.4, 0.5, 0.85], vendorUrl: "https://www.ikea.com/us/en/search/?q=dresser" },
  { slug: "two-door-wardrobe", seller: "maya", name: "Two-Door Wardrobe", category: "storage", priceCents: 54900, size: [1.0, 0.6, 2.0], vendorUrl: "https://www.ikea.com/us/en/search/?q=wardrobe" },
];

// Published demo rooms, all built from one scan (seed/scans/*.json, else SampleRoom.json). Room i takes
// the i-th best-fitting product of each placement's category, so the rooms show different products.
export const rooms: { slug: string; title: string; ownerIndex: number }[] = [
  { slug: "sunlit-living-room", title: "Sunlit Living Room", ownerIndex: 0 },
  { slug: "cozy-reading-corner", title: "Cozy Reading Corner", ownerIndex: 1 },
  { slug: "minimal-studio", title: "Minimal Studio", ownerIndex: 2 },
  { slug: "scandi-lounge", title: "Scandi Lounge", ownerIndex: 3 },
  { slug: "movie-night-den", title: "Movie Night Den", ownerIndex: 0 },
  { slug: "warm-walnut-living", title: "Warm Walnut Living", ownerIndex: 1 },
  { slug: "industrial-loft", title: "Industrial Loft", ownerIndex: 2 },
  { slug: "clay-and-cane", title: "Clay and Cane", ownerIndex: 3 },
  { slug: "weekend-guest-room", title: "Weekend Guest Room", ownerIndex: 0 },
  { slug: "makers-corner", title: "Maker's Corner", ownerIndex: 2 },
];
