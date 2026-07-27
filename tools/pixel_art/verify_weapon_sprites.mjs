import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const projectRoot = path.resolve(process.argv[2] ?? ".");
const assetDir = path.join(projectRoot, "asset", "images", "weapons");
const manifest = JSON.parse(
  fs.readFileSync(path.join(assetDir, "style_samples", "weapon_sprite_manifest.json"), "utf8")
);
const expectedCanvas = manifest.canvas ?? [22, 40];
const failures = [];
const results = [];

const palettes = {
  kinetic: { O: "4,15,27,255", E: "10,29,44,255", D: "145,60,25,255", M: "236,126,17,255", L: "255,205,61,255", S: "255,255,255,255" },
  energy: { O: "4,15,27,255", E: "10,29,44,255", D: "19,86,177,255", M: "25,202,225,255", L: "176,248,255,255", S: "255,255,255,255" },
  freeze: { O: "4,15,27,255", E: "10,29,44,255", D: "43,91,171,255", M: "80,188,232,255", L: "200,246,255,255", S: "255,255,255,255" },
  fire: { O: "4,15,27,255", E: "10,29,44,255", D: "164,42,38,255", M: "240,81,28,255", L: "255,181,45,255", S: "255,255,255,255" },
  plasma: { O: "4,15,27,255", E: "10,29,44,255", D: "91,48,166,255", M: "203,69,225,255", L: "244,194,255,255", S: "255,255,255,255" },
  support: { O: "4,15,27,255", E: "10,29,44,255", D: "19,105,101,255", M: "40,185,147,255", L: "192,255,225,255", S: "255,255,255,255" },
};

function pixel(raw, width, x, y) {
  const offset = (y * width + x) * 4;
  return `${raw[offset]},${raw[offset + 1]},${raw[offset + 2]},${raw[offset + 3]}`;
}

function visibleColorCount(raw) {
  const colors = new Set();
  for (let offset = 0; offset < raw.length; offset += 4) {
    if (raw[offset + 3] !== 0) {
      colors.add(`${raw[offset]},${raw[offset + 1]},${raw[offset + 2]},${raw[offset + 3]}`);
    }
  }
  return colors.size;
}

function opaqueComponents(raw, width, height) {
  const seen = new Set();
  let components = 0;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const key = y * width + x;
      if (seen.has(key) || pixel(raw, width, x, y).endsWith(",0")) continue;
      components += 1;
      const queue = [[x, y]];
      seen.add(key);
      while (queue.length > 0) {
        const [cx, cy] = queue.shift();
        for (const [nx, ny] of [[cx - 1, cy], [cx + 1, cy], [cx, cy - 1], [cx, cy + 1]]) {
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          const next = ny * width + nx;
          if (seen.has(next) || pixel(raw, width, nx, ny).endsWith(",0")) continue;
          seen.add(next);
          queue.push([nx, ny]);
        }
      }
    }
  }
  return components;
}

function coreMismatches(raw, width, sprite) {
  const [cx, cy] = sprite.crystal_core;
  const palette = palettes[sprite.attribute];
  const issues = [];
  sprite.core_pattern.forEach((row, py) => {
    [...row].forEach((role, px) => {
      if (role === ".") return;
      if (pixel(raw, width, cx - 6 + px, cy - 6 + py) !== palette[role]) {
        issues.push(`${px},${py}:${role}`);
      }
    });
  });
  return issues;
}

for (const sprite of manifest.sprites) {
  const spritePath = path.join(assetDir, sprite.file);
  const issues = [];
  if (!fs.existsSync(spritePath)) {
    failures.push(`${sprite.file}: missing`);
    continue;
  }
  const { data, info } = await sharp(spritePath).ensureAlpha().raw()
    .toBuffer({ resolveWithObject: true });
  const colors = visibleColorCount(data);
  const components = opaqueComponents(data, info.width, info.height);
  const coreIssues = coreMismatches(data, info.width, sprite);
  const [, , attackWidth, attackHeight] = sprite.attack_bbox;
  const attackShare = attackHeight / info.height;

  if (info.width !== expectedCanvas[0] || info.height !== expectedCanvas[1]) {
    issues.push(`dimensions ${info.width}x${info.height}`);
  }
  if (colors > manifest.max_colors) issues.push(`${colors} visible colors`);
  if (!pixel(data, info.width, 0, 0).endsWith(",0")) issues.push("opaque top-left corner");
  if (components !== 1) issues.push(`${components} opaque components`);
  if (coreIssues.length > 0) issues.push(`core mismatch ${coreIssues.slice(0, 3).join(";")}`);
  if (attackWidth < 3 || attackHeight < 15 || attackShare < 0.375) {
    issues.push(`insufficient attack prominence ${attackWidth}x${attackHeight}`);
  }
  if (issues.length > 0) failures.push(`${sprite.file}: ${issues.join(", ")}`);
  results.push({
    file: sprite.file,
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
