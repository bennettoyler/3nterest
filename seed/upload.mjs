#!/usr/bin/env node
// Uploads every file in seed/models, seed/thumbs and seed/instructions to Convex storage
// and patches the matching product or room URL field. Run after `npx convex run seed:run`.
// File names are slugs: seed/models/<product>.usdz, seed/thumbs/<product>.jpg,
// seed/thumbs/room-<room>.jpg, seed/instructions/<product>.pdf.
import { execFileSync } from "node:child_process";
import { readdirSync, readFileSync, existsSync } from "node:fs";
import { join, extname, basename, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const folders = {
  models: { field: "modelUrl", type: "model/vnd.usdz+zip" },
  thumbs: { field: "thumbnailUrl", type: "image/jpeg" },
  instructions: { field: "instructionsUrl", type: "application/pdf" },
};

function convexRun(fn, args) {
  const out = execFileSync("npx", ["convex", "run", fn, JSON.stringify(args)], {
    cwd: join(root, ".."),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  });
  return JSON.parse(out.trim());
}

let patched = 0;
for (const [folder, { field, type }] of Object.entries(folders)) {
  const dir = join(root, folder);
  if (!existsSync(dir)) continue;
  for (const file of readdirSync(dir)) {
    if (file.startsWith(".")) continue;
    const name = basename(file, extname(file));
    const isRoom = name.startsWith("room-");
    const uploadUrl = convexRun("files:generateUploadUrl", {});
    const res = await fetch(uploadUrl, {
      method: "POST",
      headers: { "Content-Type": type },
      body: readFileSync(join(dir, file)),
    });
    if (!res.ok) throw new Error(`Upload of ${file} failed: ${res.status} ${await res.text()}`);
    const { storageId } = await res.json();
    const url = convexRun("seed:attachFile", {
      table: isRoom ? "rooms" : "products",
      slug: isRoom ? name.slice(5) : name,
      field,
      storageId,
    });
    console.log(url ? `${folder}/${file} → ${url}` : `${folder}/${file}: no matching row, skipped`);
    if (url) patched++;
  }
}
console.log(`Patched ${patched} URL fields.`);
