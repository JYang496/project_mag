import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const WIDTH = 48;
const HEIGHT = 64;
const MAX_COLORS = 12;
const CONCEPT_DIR = path.resolve("asset/images/weapons/concepts_hd");
const OUTPUT_DIR = path.resolve(process.argv[2] ?? "tmp/weapon_redraw/hd_complete");

const P = Object.freeze({
  outline: [4, 15, 27, 255],
  edge: [10, 29, 44, 255],
  deep: [20, 43, 58, 255],
  metal: [47, 71, 83, 255],
  mid: [86, 112, 121, 255],
  lightMetal: [142, 168, 176, 255],
  armorShade: [194, 211, 218, 255],
  armor: [239, 246, 248, 255],
  shine: [255, 255, 255, 255],
});
const A = Object.freeze({
  kinetic: {
    dark: [145, 60, 25, 255], main: [236, 126, 17, 255], light: [255, 205, 61, 255],
  },
  energy: {
    dark: [19, 86, 177, 255], main: [25, 202, 225, 255], light: [176, 248, 255, 255],
  },
  freeze: {
    dark: [43, 91, 171, 255], main: [80, 188, 232, 255], light: [200, 246, 255, 255],
  },
  fire: {
    dark: [164, 42, 38, 255], main: [240, 81, 28, 255], light: [255, 181, 45, 255],
  },
  plasma: {
    dark: [91, 48, 166, 255], main: [203, 69, 225, 255], light: [244, 194, 255, 255],
  },
  support: {
    dark: [19, 105, 101, 255], main: [40, 185, 147, 255], light: [192, 255, 225, 255],
  },
});

const CORE_PATTERN = Object.freeze([
  "...OOOOOOO...",
  "..OOEEEEEOO..",
  ".OEEEEEEEEEO.",
  "OEEEEDMDEEEEO",
  "OEEEDMLMDEEEO",
  "OEEDMLSLMDEEO",
  "OEEDLMSMLDEEO",
  "OEEDMLMLMDEEO",
  "OEEEDMLMDEEEO",
  "OEEEEDMDEEEEO",
  ".OEEEEEEEEEO.",
  "..OOEEEEEOO..",
  "...OOOOOOO...",
]);

const SPECS = Object.freeze([
  { file: "machine_gun.png", attribute: "kinetic", core: [24, 40], attack: [15, 1, 25, 34] },
  { file: "mg2.png", attribute: "kinetic", core: [24, 43], attack: [8, 1, 32, 34], branchOf: "machine_gun" },
  { file: "blaster.png", attribute: "energy", core: [24, 41], attack: [12, 1, 24, 31] },
  { file: "spear_launcher.png", attribute: "kinetic", core: [24, 42], attack: [14, 1, 20, 36] },
  { file: "shotgun.png", attribute: "kinetic", core: [24, 40], attack: [9, 1, 30, 34] },
  { file: "pistol.png", attribute: "kinetic", core: [24, 38], attack: [17, 1, 14, 32] },
  { file: "orbit.png", attribute: "support", core: [24, 31], attack: [3, 1, 42, 28] },
  { file: "rocket_launcher.png", attribute: "fire", core: [24, 42], attack: [5, 1, 38, 31] },
  { file: "laser.png", attribute: "energy", core: [24, 46], attack: [13, 1, 22, 40] },
  { file: "chainsaw_launcher.png", attribute: "kinetic", core: [24, 45], attack: [9, 1, 30, 39] },
  { file: "dash_blade.png", attribute: "energy", core: [24, 42], attack: [14, 1, 20, 40] },
  { file: "flamethrower.png", attribute: "fire", core: [24, 41], attack: [7, 1, 34, 31] },
  { file: "plasma_lance.png", attribute: "plasma", core: [24, 43], attack: [14, 1, 20, 40] },
  { file: "glacier_projector.png", attribute: "freeze", core: [24, 36], attack: [5, 1, 38, 29] },
  { file: "cannon2.png", attribute: "kinetic", core: [24, 46], attack: [4, 1, 40, 36] },
  { file: "cannon3.png", attribute: "freeze", core: [24, 38], attack: [4, 1, 40, 32], branchOf: "cannon2" },
  { file: "sniper.png", attribute: "kinetic", core: [26, 46], attack: [12, 1, 28, 42] },
]);

function colorDistance(left, right) {
  return (
    (left[0] - right[0]) ** 2
    + (left[1] - right[1]) ** 2
    + (left[2] - right[2]) ** 2
  );
}

function isChroma(color, key) {
  return (
    color[0] > 145
    && color[2] > 125
    && color[1] < 180
    && colorDistance(color, key) < 26000
  );
}

function removeConnectedChroma(data, width, height) {
  const key = [data[0], data[1], data[2]];
  const seen = new Uint8Array(width * height);
  const queue = [];
  for (let x = 0; x < width; x += 1) {
    queue.push([x, 0], [x, height - 1]);
  }
  for (let y = 0; y < height; y += 1) {
    queue.push([0, y], [width - 1, y]);
  }
  let cursor = 0;
  while (cursor < queue.length) {
    const [x, y] = queue[cursor];
    cursor += 1;
    const index = y * width + x;
    if (seen[index]) continue;
    seen[index] = 1;
    const offset = index * 4;
    const color = [data[offset], data[offset + 1], data[offset + 2]];
    if (!isChroma(color, key)) continue;
    data[offset + 3] = 0;
    if (x > 0) queue.push([x - 1, y]);
    if (x + 1 < width) queue.push([x + 1, y]);
    if (y > 0) queue.push([x, y - 1]);
    if (y + 1 < height) queue.push([x, y + 1]);
  }
}

function opaqueBounds(data, width, height) {
  let minX = width; let minY = height; let maxX = -1; let maxY = -1;
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      if (data[(y * width + x) * 4 + 3] === 0) continue;
      minX = Math.min(minX, x); minY = Math.min(minY, y);
      maxX = Math.max(maxX, x); maxY = Math.max(maxY, y);
    }
  }
  if (maxX < minX || maxY < minY) throw new Error("concept has no opaque subject");
  return { left: minX, top: minY, width: maxX - minX + 1, height: maxY - minY + 1 };
}

function keepLargestComponent(data, width, height) {
  const seen = new Uint8Array(width * height);
  const components = [];
  for (let y = 0; y < height; y += 1) {
    for (let x = 0; x < width; x += 1) {
      const start = y * width + x;
      if (seen[start] || data[start * 4 + 3] === 0) continue;
      const queue = [start];
      const component = [];
      seen[start] = 1;
      let cursor = 0;
      while (cursor < queue.length) {
        const index = queue[cursor];
        cursor += 1;
        component.push(index);
        const cx = index % width;
        const cy = Math.floor(index / width);
        for (const [nx, ny] of [[cx - 1, cy], [cx + 1, cy], [cx, cy - 1], [cx, cy + 1]]) {
          if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
          const next = ny * width + nx;
          if (seen[next] || data[next * 4 + 3] === 0) continue;
          seen[next] = 1;
          queue.push(next);
        }
      }
      components.push(component);
    }
  }
  components.sort((left, right) => right.length - left.length);
  for (const component of components.slice(1)) {
    for (const index of component) data[index * 4 + 3] = 0;
  }
}

function paletteFor(attribute) {
  return [...Object.values(P), ...Object.values(A[attribute])];
}

function quantizeToRolePalette(data, attribute) {
  const palette = paletteFor(attribute);
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] < 128) {
      data[offset] = 0; data[offset + 1] = 0; data[offset + 2] = 0; data[offset + 3] = 0;
      continue;
    }
    const source = [data[offset], data[offset + 1], data[offset + 2]];
    let nearest = palette[0];
    let nearestDistance = Number.POSITIVE_INFINITY;
    for (const candidate of palette) {
      const distance = colorDistance(source, candidate);
      if (distance < nearestDistance) {
        nearest = candidate;
        nearestDistance = distance;
      }
    }
    data[offset] = nearest[0];
    data[offset + 1] = nearest[1];
    data[offset + 2] = nearest[2];
    data[offset + 3] = 255;
  }
}

function stampCore(data, cx, cy, attribute) {
  const roles = {
    O: P.outline,
    E: P.edge,
    D: A[attribute].dark,
    M: A[attribute].main,
    L: A[attribute].light,
    S: P.shine,
  };
  CORE_PATTERN.forEach((line, py) => {
    [...line].forEach((role, px) => {
      if (role === ".") return;
      const x = cx - 6 + px;
      const y = cy - 6 + py;
      const color = roles[role];
      const offset = (y * WIDTH + x) * 4;
      data.set(color, offset);
    });
  });
}

async function buildSprite(spec) {
  const conceptPath = path.join(CONCEPT_DIR, spec.file);
  const loaded = await sharp(conceptPath).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  removeConnectedChroma(loaded.data, loaded.info.width, loaded.info.height);
  const bounds = opaqueBounds(loaded.data, loaded.info.width, loaded.info.height);
  const trimmed = await sharp(loaded.data, {
    raw: { width: loaded.info.width, height: loaded.info.height, channels: 4 },
  }).extract(bounds).raw().toBuffer({ resolveWithObject: true });
  const fitted = await sharp(trimmed.data, {
    raw: { width: trimmed.info.width, height: trimmed.info.height, channels: 4 },
  }).resize(44, 60, {
    fit: "contain",
    kernel: "nearest",
    background: { r: 0, g: 0, b: 0, alpha: 0 },
  }).extend({
    top: 2, bottom: 2, left: 2, right: 2,
    background: { r: 0, g: 0, b: 0, alpha: 0 },
  }).raw().toBuffer({ resolveWithObject: true });
  keepLargestComponent(fitted.data, WIDTH, HEIGHT);
  quantizeToRolePalette(fitted.data, spec.attribute);
  stampCore(fitted.data, spec.core[0], spec.core[1], spec.attribute);
  return fitted.data;
}

function visibleColors(data) {
  const colors = new Set();
  for (let offset = 0; offset < data.length; offset += 4) {
    if (data[offset + 3] !== 0) {
      colors.add(`${data[offset]},${data[offset + 1]},${data[offset + 2]}`);
    }
  }
  return colors.size;
}

async function saveSprite(data, outputPath) {
  await sharp(data, { raw: { width: WIDTH, height: HEIGHT, channels: 4 } })
    .png({ palette: true, colours: 16 })
    .toFile(outputPath);
}

async function buildPreview(items) {
  const columns = 6;
  const panelWidth = 224;
  const panelHeight = 300;
  const scale = 4;
  const composites = [];
  for (let index = 0; index < items.length; index += 1) {
    const item = items[index];
    const column = index % columns;
    const previewRow = Math.floor(index / columns);
    const sprite = await sharp(item.data, {
      raw: { width: WIDTH, height: HEIGHT, channels: 4 },
    }).resize(WIDTH * scale, HEIGHT * scale, { kernel: "nearest" }).png().toBuffer();
    composites.push({
      input: sprite,
      left: column * panelWidth + Math.floor((panelWidth - WIDTH * scale) / 2),
      top: previewRow * panelHeight + 32,
    });
    composites.push({
      input: Buffer.from(
        `<svg width="${panelWidth}" height="28"><style>text{font:14px sans-serif;fill:#e9f2f2}</style>`
        + `<text x="7" y="19">${item.spec.file}</text></svg>`
      ),
      left: column * panelWidth,
      top: previewRow * panelHeight,
    });
  }
  await sharp({
    create: {
      width: columns * panelWidth,
      height: 3 * panelHeight,
      channels: 4,
      background: { r: 13, g: 22, b: 31, alpha: 1 },
    },
  }).composite(composites).png().toFile(path.join(OUTPUT_DIR, "weapon_set_preview.png"));
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const items = [];
  const sprites = [];
  for (const spec of SPECS) {
    const data = await buildSprite(spec);
    const colors = visibleColors(data);
    if (colors > MAX_COLORS) throw new Error(`${spec.file}: ${colors} colors`);
    await saveSprite(data, path.join(OUTPUT_DIR, spec.file));
    items.push({ spec, data });
    sprites.push({
      file: spec.file,
      width: WIDTH,
      height: HEIGHT,
      visible_colors: colors,
      attribute: spec.attribute,
      crystal_core: spec.core,
      core_pattern: CORE_PATTERN,
      attack_bbox: spec.attack,
      branch_of: spec.branchOf ?? null,
      concept_source: `concepts_hd/${spec.file}`,
    });
  }
  await buildPreview(items);
  fs.writeFileSync(
    path.join(OUTPUT_DIR, "weapon_sprite_manifest.json"),
    `${JSON.stringify({
      schema_version: 4,
      canvas: [WIDTH, HEIGHT],
      runtime_target_height: HEIGHT,
      max_colors: MAX_COLORS,
      sprites,
    }, null, 2)}\n`
  );
  process.stdout.write(`${OUTPUT_DIR}\n`);
}

await main();
