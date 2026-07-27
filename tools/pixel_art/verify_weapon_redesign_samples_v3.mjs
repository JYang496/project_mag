import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");
const root = path.resolve(process.argv[2] ?? "asset/images/weapons/redesign_samples_v3");
const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
const results = [];
const failures = [];

const rolePalettes = {
  kinetic: {
    O: "5,18,31,255", D: "145,60,25,255", M: "236,126,17,255",
    L: "255,205,61,255", S: "255,255,255,255",
  },
  energy: {
    O: "5,18,31,255", D: "19,86,177,255", M: "25,202,225,255",
    L: "176,248,255,255", S: "255,255,255,255",
  },
  freeze: {
    O: "5,18,31,255", D: "43,91,171,255", M: "80,188,232,255",
    L: "200,246,255,255", S: "255,255,255,255",
  },
};

function pixel(data, width, x, y) {
  const offset = (y * width + x) * 4;
  return `${data[offset]},${data[offset + 1]},${data[offset + 2]},${data[offset + 3]}`;
}

function countColors(data) {
  const colors = new Set();
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] !== 0) {
      colors.add(`${data[offset]},${data[offset + 1]},${data[offset + 2]},${data[offset + 3]}`);
    }
  }
  return colors.size;
}

function countOpaqueComponents(data, width, height) {
  const seen = new Set();
  let components = 0;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const key = y * width + x;
      if (seen.has(key) || pixel(data, width, x, y).endsWith(",0")) continue;
      components += 1;
      const queue = [[x, y]];
      seen.add(key);
      while (queue.length > 0) {
        const [cx, cy] = queue.shift();
        for (const [nx, ny] of [[cx - 1, cy], [cx + 1, cy], [cx, cy - 1], [cx, cy + 1]]) {
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          const nextKey = ny * width + nx;
          if (seen.has(nextKey) || pixel(data, width, nx, ny).endsWith(",0")) continue;
          seen.add(nextKey);
          queue.push([nx, ny]);
        }
      }
    }
  }
  return components;
}

function verifyCore(data, width, sample) {
  const [cx, cy] = sample.crystal_core;
  const palette = rolePalettes[sample.attribute];
  const issues = [];
  sample.core_pattern.forEach((row, py) => {
    [...row].forEach((role, px) => {
      if (role === ".") return;
      const actual = pixel(data, width, cx - 4 + px, cy - 4 + py);
      if (actual !== palette[role]) issues.push(`${px},${py}:${role}`);
    });
  });
  return issues;
}

for (const sample of manifest.samples) {
  const filePath = path.join(root, sample.file);
  const issues = [];
  if (!fs.existsSync(filePath)) {
    failures.push(`${sample.file}: missing`);
    continue;
  }
  const { data, info } = await sharp(filePath).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  const colors = countColors(data);
  const components = countOpaqueComponents(data, info.width, info.height);
  const coreIssues = verifyCore(data, info.width, sample);
  const [attackX, attackY, attackWidth, attackHeight] = sample.attack_bbox;
  const attackShare = attackHeight / info.height;

  if (info.width !== sample.width || info.height !== sample.height) {
    issues.push(`dimensions ${info.width}x${info.height}`);
  }
  if (colors > manifest.max_colors) issues.push(`${colors} colors`);
  if (!pixel(data, info.width, 0, 0).endsWith(",0")) issues.push("opaque corner");
  if (components !== 1) issues.push(`${components} opaque components`);
  if (coreIssues.length > 0) issues.push(`core mismatch (${coreIssues.slice(0, 3).join(";")})`);
  if (attackWidth < 3 || attackHeight < 16 || attackShare < 0.4) {
    issues.push(`attack bbox ${attackX},${attackY},${attackWidth},${attackHeight}`);
  }
  if (issues.length > 0) failures.push(`${sample.file}: ${issues.join(", ")}`);
  results.push({
    file: sample.file,
    dimensions: `${info.width}x${info.height}`,
    visible_colors: colors,
    opaque_components: components,
    standardized_core_pixels: coreIssues.length === 0,
    attack_height_share: Number(attackShare.toFixed(3)),
    ok: issues.length === 0,
  });
}

process.stdout.write(`${JSON.stringify({ ok: failures.length === 0, results, failures }, null, 2)}\n`);
if (failures.length > 0) process.exitCode = 1;
