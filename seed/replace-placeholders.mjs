#!/usr/bin/env node
// Replaces seeded files that still point at an earlier version of the same seed file (e.g. the
// placeholder thumbnails replaced by rendered ones). Earlier versions are taken from git history and matched
// by sha256 in one seed:fileHashes call; the mutation then patches only while the field still holds the
// matched URL, so a file the app or a person set is never replaced.
// Arguments go to `npx convex run`, e.g. `node seed/replace-placeholders.mjs --prod`.
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { readdirSync, readFileSync } from "node:fs";
import { basename, dirname, extname, join } from "node:path";
import { fileURLToPath } from "node:url";

const root = dirname(fileURLToPath(import.meta.url));
const repo = join(root, "..");
const flags = process.argv.slice(2);
const folders = {
  models: { field: "modelUrl", type: "model/vnd.usdz+zip", ext: ".usdz" },
  thumbs: { field: "thumbnailUrl", type: "image/jpeg", ext: ".jpg" },
  instructions: { field: "instructionsUrl", type: "application/pdf", ext: ".pdf" },
};

const run = (fn, args) => {
  const out = execFileSync("npx", ["convex", "run", ...flags, fn, JSON.stringify(args)], {
    cwd: repo,
    encoding: "utf8",
    stdio: ["ignore", "pipe", "inherit"],
  }).trim();
  return out ? JSON.parse(out) : null;
};
const sha = (bytes) => createHash("sha256").update(bytes).digest("base64");

function earlierHashes(path, current) {
  const commits = execFileSync("git", ["log", "--format=%H", "--", path], { cwd: repo, encoding: "utf8" })
    .trim()
    .split("\n")
    .filter(Boolean);
  const hashes = commits.map((c) =>
    sha(execFileSync("git", ["show", `${c}:${path}`], { cwd: repo, maxBuffer: 64 * 1024 * 1024 })),
  );
  return [...new Set(hashes)].filter((h) => h !== current);
}

const candidates = [];
for (const [folder, { field, type, ext }] of Object.entries(folders)) {
  for (const file of readdirSync(join(root, folder))) {
    if (extname(file) !== ext) continue;
    const path = `seed/${folder}/${file}`;
    const bytes = readFileSync(join(repo, path));
    const placeholderHashes = earlierHashes(path, sha(bytes));
    if (!placeholderHashes.length) continue;
    const name = basename(file, ext);
    const isRoom = name.startsWith("room-");
    const slugs = isRoom ? [name.slice(5), `${name.slice(5)}-scan`] : [name];
    for (const slug of slugs) {
      candidates.push({ target: { table: isRoom ? "rooms" : "products", slug, field }, path, type, bytes, placeholderHashes });
    }
  }
}

const deployed = candidates.length ? run("seed:fileHashes", { targets: candidates.map((c) => c.target) }) : [];
let replaced = 0;
for (const [i, { target, path, type, bytes, placeholderHashes }] of candidates.entries()) {
  const { url: expectedUrl, sha256 } = deployed[i];
  if (!expectedUrl || !sha256 || !placeholderHashes.includes(sha256)) continue;
  const res = await fetch(run("files:generateUploadUrl", {}), {
    method: "POST",
    headers: { "Content-Type": type },
    body: bytes,
  });
  if (!res.ok) throw new Error(`Upload of ${path} failed: ${res.status}`);
  const { storageId } = await res.json();
  const url = run("seed:replacePlaceholder", { ...target, storageId, expectedUrl });
  console.log(url ? `${path} → ${target.slug}` : `${path}: ${target.slug} changed meanwhile, left alone`);
  if (url) replaced++;
}
console.log(`Replaced ${replaced} placeholder files.`);
