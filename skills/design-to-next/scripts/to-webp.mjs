#!/usr/bin/env node
// Convert images to WebP for the design-to-next skill.
// Run from the Next.js project root (uses the project's `sharp`, which Next.js installs):
//
//   node <skill-dir>/scripts/to-webp.mjs [dir-or-file ...] [--replace] [--quality=82] [--max-width=2560]
//
// Default target: assets/images
// --replace       delete the original after a successful conversion
// Skips: .webp, .svg, .ico, .avif, animated GIFs, and anything inside public/ or app/
// (OG images, favicons and icons there keep their format for compatibility).

import { createRequire } from "node:module";
import { readdir, stat, unlink } from "node:fs/promises";
import { existsSync } from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const flags = Object.fromEntries(
  args.filter((a) => a.startsWith("--")).map((a) => {
    const [k, v] = a.slice(2).split("=");
    return [k, v ?? true];
  }),
);
const targets = args.filter((a) => !a.startsWith("--"));
if (targets.length === 0) targets.push("assets/images");

const quality = Number(flags.quality ?? 82);
const maxWidth = Number(flags["max-width"] ?? 2560);
const replace = Boolean(flags.replace);

let sharp;
try {
  const require = createRequire(path.join(process.cwd(), "package.json"));
  sharp = require("sharp");
} catch {
  console.error("sharp not found in this project. Install it first: <pm> add -D sharp");
  process.exit(2);
}

const CONVERT = new Set([".png", ".jpg", ".jpeg", ".gif", ".tif", ".tiff", ".bmp"]);
const SKIP_DIRS = new Set(["node_modules", ".next", ".git", "public", "app"]);

async function* walk(p) {
  const s = await stat(p);
  if (s.isFile()) return yield p;
  for (const entry of await readdir(p, { withFileTypes: true })) {
    if (entry.isDirectory() && SKIP_DIRS.has(entry.name)) continue;
    yield* walk(path.join(p, entry.name));
  }
}

let converted = 0, skipped = 0, failed = 0;

for (const target of targets) {
  if (!existsSync(target)) {
    console.error(`not found: ${target}`);
    failed++;
    continue;
  }
  for await (const file of walk(target)) {
    const ext = path.extname(file).toLowerCase();
    if (!CONVERT.has(ext)) continue;

    const out = file.slice(0, -ext.length) + ".webp";
    try {
      const meta = await sharp(file).metadata();
      if (ext === ".gif" && (meta.pages ?? 1) > 1) {
        console.log(`skip  ${file} (animated GIF: use a video instead, or keep it)`);
        skipped++;
        continue;
      }
      if (existsSync(out)) {
        console.log(`skip  ${file} (${path.basename(out)} already exists)`);
        skipped++;
        continue;
      }
      const img = sharp(file).rotate();
      if (meta.width && meta.width > maxWidth) img.resize({ width: maxWidth });
      await img.webp({ quality }).toFile(out);

      const [a, b] = [(await stat(file)).size, (await stat(out)).size];
      console.log(`ok    ${file} -> ${path.basename(out)}  ${(a / 1024).toFixed(0)}KB -> ${(b / 1024).toFixed(0)}KB`);
      if (replace) await unlink(file);
      converted++;
    } catch (e) {
      console.error(`fail  ${file}: ${e.message}`);
      failed++;
    }
  }
}

console.log(`\n${converted} converted, ${skipped} skipped, ${failed} failed${replace ? " (originals deleted)" : ""}`);
console.log("Update imports in constants/images.ts to the .webp files.");
process.exit(failed ? 1 : 0);
