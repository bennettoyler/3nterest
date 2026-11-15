#!/usr/bin/env node
// Demo reset (Task Z step 3), add-only: seed:run adds missing seeded rows (plus scan-built rooms from the
// newest seed/scans/*.json), seed/upload.mjs fills missing files, then smoke checks print PASS or FAIL and
// delete only the order and design they created. Nothing else is deleted or overwritten. Exits 1 on failure.
// Arguments go to `npx convex run`, e.g. `npm run demo:reset -- --prod`.
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const flags = process.argv.slice(2);
const run = (fn, args = {}) => {
  const out = execFileSync("npx", ["convex", "run", ...flags, fn, JSON.stringify(args)], {
    cwd: join(root, ".."),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
    maxBuffer: 64 * 1024 * 1024,
  }).trim();
  return out ? JSON.parse(out) : null;
};

const scansDir = join(root, "scans");
const scans = existsSync(scansDir)
  ? readdirSync(scansDir)
      .filter((f) => f.endsWith(".json"))
      .map((f) => join(scansDir, f))
      .sort((a, b) => statSync(b).mtimeMs - statSync(a).mtimeMs)
  : [];
const scan = scans[0] ? JSON.parse(readFileSync(scans[0], "utf8")) : undefined;

console.log(`Seeding from ${scans[0] ?? "Interest/Shared/SampleRoom.json"}`);
console.log(run("seed:run", scan ? { scan } : {}));
execFileSync("node", [join(root, "upload.mjs"), ...flags], { stdio: "inherit" });

let failed = 0;
const check = (name, ok, detail) => {
  if (!ok) failed++;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? `: ${detail}` : ""}`);
};

const categories = ["chair", "table", "sofa", "bed", "storage", "television", "other"];
const users = run("users:list");
const products = run("products:list");
const missing = categories.filter((c) => !products.some((p) => p.category === c));
check("products", products.length >= 16 && missing.length === 0, `${products.length} products${missing.length ? `, missing ${missing}` : ", every category"}`);

const feed = run("rooms:feed");
const { seededRooms, seededWithoutThumbnail } = run("seed:status");
check(
  "feed",
  seededRooms >= 8 && seededWithoutThumbnail === 0,
  `${feed.length} published rooms (${seededRooms} seeded, ${seededWithoutThumbnail} of them without thumbnail)`,
);

const started = Date.now();
const design = run("designs:generate", { prompt: "a 120 cm walnut desk with two drawers", userId: users[0].id });
const ms = Date.now() - started;
check("builder", design.parts.length > 0 && ms < 15000, `"${design.title}", ${design.parts.length} parts in ${ms} ms`);

const product = products.find((p) => p.priceCents > 0 && !p.designId);
let checkout;
try {
  checkout = run("payments:createCheckout", { productId: product.id, buyerId: users[1].id });
  const pendingHidden = !run("orders:bySeller", { sellerId: product.sellerId }).some((o) => o.id === checkout.orderId);
  const order = run("orders:confirm", { id: checkout.orderId });
  const fee = Math.round(product.priceCents * 0.05);
  check(
    "checkout",
    checkout.checkoutUrl.startsWith("https://") &&
      pendingHidden &&
      order.status === "paid" &&
      order.platformFeeCents === fee &&
      order.sellerCents === product.priceCents - fee,
    `${checkout.checkoutUrl}, ${order.amountCents}/${order.platformFeeCents}/${order.sellerCents}${pendingHidden ? "" : ", pending order showed in earnings"}`,
  );
} catch (error) {
  check("checkout", false, String(error).split("\n")[0]);
} finally {
  run("seed:deleteSmoke", { designId: design.id, ...(checkout ? { orderId: checkout.orderId } : {}) });
}

console.log("\nNothing created by the app was changed.");
console.log(failed ? `${failed} check(s) failed.` : "All checks passed.");
process.exit(failed ? 1 : 0);
