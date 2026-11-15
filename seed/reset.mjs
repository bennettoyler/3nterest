#!/usr/bin/env node
// Demo reset (Task Z step 3): seed:run (from the newest seed/scans/*.json, else SampleRoom.json),
// seed/upload.mjs, then smoke checks that print PASS or FAIL. Exits 1 if any check fails.
// seed:run keeps everything the app created, including seeded rooms the app saved over.
// `--scan` rebuilds the seeded rooms from the newest scan (overwriting app edits to those rooms only);
// `--full` first wipes every row and file (Task Z only).
// Other arguments go to `npx convex run`, e.g. `npm run demo:reset -- --prod`.
import { execFileSync } from "node:child_process";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const full = process.argv.includes("--full");
const replaceRooms = process.argv.includes("--scan");
const flags = process.argv.slice(2).filter((a) => a !== "--full" && a !== "--scan");
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
if (full) {
  console.log("Full reset: deleting every row and file, including what the app created.");
  run("seed:wipeAll");
}
console.log(run("seed:run", { ...(scan ? { scan } : {}), ...(replaceRooms ? { replaceRooms } : {}) }));
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
const blank = feed.filter((r) => !r.thumbnailUrl).length;
check("feed", feed.length >= 8 && feed.length <= 12 && blank === 0, `${feed.length} published rooms, ${blank} without thumbnail`);

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

console.log(
  full
    ? "\nFull reset: rooms, orders and designs created in the app are gone."
    : "\nRooms, orders and designs created in the app were kept; ids are unchanged.",
);
console.log(failed ? `${failed} check(s) failed.` : "All checks passed.");
process.exit(failed ? 1 : 0);
