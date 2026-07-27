import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const root = path.resolve(
  process.argv[2] ?? "asset/images/weapons/redesign_samples_v2"
);
const manifest = JSON.parse(
  fs.readFileSync(path.join(root, "manifest.json"), "utf8")
);
const outline = [5, 18, 31, 255];
const results = [];
const failures = [];

function pixelAt(data, width, x, y) {
  const offset = (y * width + x) * 4;
  return [data[offset], data[offset + 1], data[offset + 2], data[offset + 3]];
}

function sameColor(left, right) {
  return left.every((value, index) => value === right[index]);
}

function countColors(data) {
  const colors = new Set();
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] === 0) continue;
    colors.add(`${data[offset]},${data[offset + 1]},${data[offset + 2]},${data[offset + 3]}`);
  }
  return colors.size;
}

function countOpaqueComponents(data, width, height) {
  const visited = new Set();
  let components = 0;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const key = y * width + x;
      if (visited.has(key) || pixelAt(data, width, x, y)[3] === 0) continue;
      components += 1;
      const queue = [[x, y]];
      visited.add(key);
      while (queue.length > 0) {
        const [currentX, currentY] = queue.shift();
        for (const [nextX, nextY] of [
          [currentX - 1, currentY],
          [currentX + 1, currentY],
          [currentX, currentY - 1],
          [currentX, currentY + 1],
        ]) {
          if (nextX < 0 || nextY < 0 || nextX >= width || nextY >= height) continue;
          const nextKey = nextY * width + nextX;
          if (visited.has(nextKey) || pixelAt(data, width, nextX, nextY)[3] === 0) continue;
          visited.add(nextKey);
          queue.push([nextX, nextY]);
        }
      }
    }
  }
  return components;
}

for (const sample of manifest.samples) {
  const filePath = path.join(root, sample.file);
  const issues = [];
  if (!fs.existsSync(filePath)) {
    failures.push(`${sample.file}: missing`);
    continue;
  }
  const { data, info } = await sharp(filePath)
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  const colors = countColors(data);
  const components = countOpaqueComponents(data, info.width, info.height);
  const [coreX, coreY] = sample.crystal_core;
  const cardinalRing = [
    pixelAt(data, info.width, coreX, coreY - 3),
    pixelAt(data, info.width, coreX - 3, coreY),
    pixelAt(data, info.width, coreX + 3, coreY),
    pixelAt(data, info.width, coreX, coreY + 3),
  ].every((color) => sameColor(color, outline));
  const center = pixelAt(data, info.width, coreX, coreY);
  if (info.width !== sample.width || info.height !== sample.height) {
    issues.push(`dimensions ${info.width}x${info.height}`);
  }
  if (colors > manifest.max_colors) issues.push(`${colors} colors`);
  if (pixelAt(data, info.width, 0, 0)[3] !== 0) issues.push("opaque corner");
  if (components !== 1) issues.push(`${components} opaque components`);
  if (!cardinalRing || center[3] !== 255 || sameColor(center, outline)) {
    issues.push("invalid faceted crystal core");
  }
  if (issues.length > 0) failures.push(`${sample.file}: ${issues.join(", ")}`);
  results.push({
    file: sample.file,
    dimensions: `${info.width}x${info.height}`,
    visible_colors: colors,
    opaque_components: components,
    crystal_core: `${coreX},${coreY}`,
    ok: issues.length === 0,
  });
}

process.stdout.write(`${JSON.stringify({ ok: failures.length === 0, results, failures }, null, 2)}\n`);
if (failures.length > 0) process.exitCode = 1;
