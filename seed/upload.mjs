#!/usr/bin/env node
// Uploads every file in seed/models, seed/thumbs and seed/instructions to Convex storage
// and patches the matching product or room URL field. Run after `npx convex run seed:run`.
// File names are slugs: seed/models/<product>.usdz, seed/thumbs/<product>.jpg,
// seed/thumbs/room-<room>.jpg, seed/instructions/<product>.pdf.
// Only fields that are still empty are filled; `--replace` re-uploads everything (e.g. new model files).
// Other arguments go to `npx convex run`, e.g. `node seed/upload.mjs --prod`.
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join, extname, basename, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const replace = process.argv.includes("--replace");
const flags = process.argv.slice(2).filter((a) => a !== "--replace");
const folders = {
  models: { field: "modelUrl", type: "model/vnd.usdz+zip", ext: ".usdz" },
  thumbs: { field: "thumbnailUrl", type: "image/jpeg", ext: ".jpg" },
  instructions: { field: "instructionsUrl", type: "application/pdf", ext: ".pdf" },
};

function convexRun(fn, args) {
  const out = execFileSync("npx", ["convex", "run", ...flags, fn, JSON.stringify(args)], {
    cwd: join(root, ".."),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  return out.trim() ? JSON.parse(out.trim()) : null;
}

let patched = 0;
for (const [folder, { field, type, ext }] of Object.entries(folders)) {
  const dir = join(root, folder);
  if (!existsSync(dir)) continue;
  for (const file of readdirSync(dir)) {
    if (file.startsWith(".") || extname(file) !== ext) continue;
    const name = basename(file, extname(file));
    const isRoom = name.startsWith("room-");
    const target = { table: isRoom ? "rooms" : "products", slug: isRoom ? name.slice(5) : name, field };
    if (!replace && !convexRun("seed:needsFile", target)) continue;
    const uploadUrl = convexRun("files:generateUploadUrl", {});
    const res = await fetch(uploadUrl, {
      method: "POST",
      headers: { "Content-Type": type },
      body: readFileSync(join(dir, file)),
    });
    if (!res.ok) throw new Error(`Upload of ${file} failed: ${res.status} ${await res.text()}`);
    const { storageId } = await res.json();
    const url = convexRun("seed:attachFile", { ...target, storageId });
    console.log(url ? `${folder}/${file} → ${url}` : `${folder}/${file}: no matching row, skipped`);
    if (url) patched++;
  }
}
console.log(`Patched ${patched} URL fields.`);
