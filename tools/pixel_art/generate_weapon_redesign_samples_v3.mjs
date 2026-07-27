import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const HEIGHT = 40;
const MAX_COLORS = 12;
const OUTPUT_DIR = path.resolve(
  process.argv[2] ?? "asset/images/weapons/redesign_samples_v3"
);

const P = Object.freeze({
  outline: [5, 18, 31, 255],
  deep: [16, 39, 54, 255],
  panel: [55, 79, 91, 255],
  lightMetal: [134, 158, 167, 255],
  armorShade: [198, 214, 220, 255],
  armor: [242, 247, 248, 255],
  shine: [255, 255, 255, 255],
});
const KINETIC = Object.freeze({
  dark: [145, 60, 25, 255],
  main: [236, 126, 17, 255],
  light: [255, 205, 61, 255],
});
const ENERGY = Object.freeze({
  dark: [19, 86, 177, 255],
  main: [25, 202, 225, 255],
  light: [176, 248, 255, 255],
});
const FREEZE = Object.freeze({
  dark: [43, 91, 171, 255],
  main: [80, 188, 232, 255],
  light: [200, 246, 255, 255],
});

// This role map is stamped without variation on every weapon. Only D/M/L colors
// change by attribute. "S" always uses the shared pure-white highlight.
const CORE_PATTERN = Object.freeze([
  "..OOOOO..",
  ".OODDDOO.",
  "ODDMLMDDO",
  "ODMLSLMDO",
  "ODLMSMLDO",
  "ODMLMLMDO",
  "ODDMLMDDO",
  ".OODDDOO.",
  "..OOOOO..",
]);

function createImage(width) {
  return { width, height: HEIGHT, pixels: Buffer.alloc(width * HEIGHT * 4, 0) };
}

function setPixel(image, x, y, color) {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;
  const offset = (y * image.width + x) * 4;
  image.pixels.set(color, offset);
}

function rect(image, x, y, width, height, color) {
  for (let py = y; py < y + height; py += 1) {
    for (let px = x; px < x + width; px += 1) setPixel(image, px, py, color);
  }
}

function rows(image, startY, definitions, color) {
  definitions.forEach(([x, width], index) => rect(image, x, startY + index, width, 1, color));
}

function stampCore(image, centerX, centerY, accent) {
  const colors = { O: P.outline, D: accent.dark, M: accent.main, L: accent.light, S: P.shine };
  CORE_PATTERN.forEach((row, py) => {
    [...row].forEach((role, px) => {
      if (role !== ".") setPixel(image, centerX - 4 + px, centerY - 4 + py, colors[role]);
    });
  });
}

function drawMachineGun() {
  const image = createImage(22);

  // The firing mechanism owns the upper 60% of the silhouette.
  rows(image, 0, [[9, 4], [8, 6], [8, 6], [7, 8], [7, 8]], P.outline);
  rect(image, 9, 1, 4, 3, P.lightMetal);
  rect(image, 10, 1, 1, 3, P.shine);
  rect(image, 8, 4, 6, 2, P.deep);
  rows(image, 6, Array(15).fill([7, 8]), P.outline);
  rect(image, 8, 6, 6, 14, P.panel);
  rect(image, 9, 6, 2, 14, P.lightMetal);
  rect(image, 11, 6, 1, 14, P.armorShade);
  rect(image, 12, 7, 1, 12, P.deep);
  rect(image, 8, 10, 6, 1, P.outline);
  rect(image, 8, 15, 6, 1, P.outline);

  // Compact receiver and a small integrated ammunition drum.
  rows(image, 19, [[6, 11], [5, 13], [4, 15], [4, 15], [4, 15], [4, 15],
    [4, 15], [4, 15], [4, 15], [5, 13], [5, 13], [6, 11], [7, 9]], P.outline);
  rect(image, 6, 21, 10, 10, P.armor);
  rect(image, 6, 21, 2, 9, P.armorShade);
  rect(image, 14, 22, 2, 8, P.shine);
  rows(image, 22, [[17, 3], [17, 4], [17, 4], [17, 4], [17, 4],
    [17, 4], [17, 3]], P.outline);
  rect(image, 18, 23, 2, 5, P.panel);
  setPixel(image, 19, 24, KINETIC.light);
  setPixel(image, 19, 26, KINETIC.main);

  // Short, functional rear grip.
  rows(image, 31, [[8, 6], [8, 6], [9, 4], [9, 4], [9, 4],
    [8, 6], [8, 6], [7, 8], [8, 6]], P.outline);
  rect(image, 9, 32, 4, 5, P.panel);
  rect(image, 10, 33, 2, 1, P.lightMetal);
  rect(image, 9, 37, 4, 1, P.armor);

  stampCore(image, 10, 25, KINETIC);
  return {
    name: "machine_gun_v3",
    image,
    core: [10, 25],
    attack_bbox: [7, 0, 8, 21],
    attribute: "kinetic",
  };
}

function drawDashBlade() {
  const image = createImage(19);

  // A 27px blade makes the attack surface the first and largest read.
  rows(image, 0, [[9, 1], [8, 3], [8, 3], [7, 5], [7, 5], [6, 7],
    [6, 7], [6, 7], [6, 7], [6, 7], [6, 7], [6, 7], [6, 7],
    [6, 7], [6, 7], [6, 7], [6, 7], [6, 7], [6, 7], [6, 7],
    [6, 7], [6, 7], [6, 7], [6, 7], [6, 7], [7, 5], [7, 5]], P.outline);
  rows(image, 1, [[9, 1], [8, 3], [8, 3], [7, 5], [7, 5], [7, 5],
    [7, 5], [7, 5], [7, 5], [7, 5], [7, 5], [7, 5], [7, 5],
    [7, 5], [7, 5], [7, 5], [7, 5], [7, 5], [7, 5], [7, 5],
    [7, 5], [7, 5], [7, 5], [7, 5], [8, 3]], ENERGY.main);
  rect(image, 8, 3, 2, 22, ENERGY.light);
  rect(image, 10, 4, 1, 21, P.shine);
  rect(image, 11, 7, 1, 17, ENERGY.dark);

  // Compact guard fins: support the blade without competing with it.
  rows(image, 24, [[3, 13], [2, 15], [1, 17], [2, 15], [3, 13],
    [4, 11], [5, 9], [5, 9], [6, 7]], P.outline);
  rows(image, 25, [[4, 3], [3, 4], [4, 3], [5, 2]], P.armor);
  rows(image, 25, [[12, 3], [12, 4], [12, 3], [12, 2]], P.armorShade);
  setPixel(image, 5, 26, P.shine);
  setPixel(image, 13, 26, P.armor);

  rows(image, 32, [[7, 5], [7, 5], [7, 5], [7, 5], [7, 5],
    [6, 7], [7, 5], [8, 3]], P.outline);
  rect(image, 8, 32, 3, 5, P.panel);
  rect(image, 9, 33, 1, 1, P.lightMetal);
  rect(image, 8, 37, 3, 1, P.armor);

  stampCore(image, 9, 28, ENERGY);
  return {
    name: "dash_blade_v3",
    image,
    core: [9, 28],
    attack_bbox: [6, 0, 7, 27],
    attribute: "energy",
  };
}

function drawGlacierProjector() {
  const image = createImage(23);

  // Three broad emitter prongs dominate the upper half.
  rows(image, 0, [[10, 3], [9, 5], [9, 5], [8, 7], [8, 7], [8, 7],
    [8, 7], [8, 7], [8, 7], [8, 7], [8, 7], [8, 7], [8, 7],
    [8, 7], [8, 7], [8, 7]], P.outline);
  rect(image, 10, 1, 3, 14, FREEZE.main);
  rect(image, 10, 1, 1, 13, FREEZE.light);
  rect(image, 12, 3, 1, 11, P.shine);

  rows(image, 3, [[3, 3], [2, 5], [1, 7], [1, 7], [1, 7], [1, 7],
    [1, 7], [2, 6], [2, 6], [3, 5], [3, 5], [4, 4]], P.outline);
  rows(image, 4, [[4, 1], [3, 3], [2, 5], [2, 5], [2, 5], [2, 5],
    [2, 5], [3, 4], [3, 4], [4, 3]], FREEZE.main);
  rows(image, 3, [[17, 3], [16, 5], [15, 7], [15, 7], [15, 7], [15, 7],
    [15, 7], [15, 6], [15, 6], [15, 5], [15, 5], [15, 4]], P.outline);
  rows(image, 4, [[18, 1], [17, 3], [16, 5], [16, 5], [16, 5], [16, 5],
    [16, 5], [16, 4], [16, 4], [16, 3]], FREEZE.main);
  rect(image, 3, 6, 1, 6, FREEZE.light);
  rect(image, 18, 6, 1, 6, P.shine);

  // Small body; coolant cells are integrated, not silhouette-sized tanks.
  rows(image, 14, [[6, 11], [5, 13], [4, 15], [4, 15], [3, 17],
    [3, 17], [3, 17], [3, 17], [3, 17], [3, 17], [3, 17],
    [3, 17], [4, 15], [4, 15], [5, 13], [5, 13], [6, 11],
    [6, 11], [7, 9], [7, 9]], P.outline);
  rect(image, 5, 16, 13, 15, P.armor);
  rect(image, 5, 17, 2, 12, P.armorShade);
  rect(image, 16, 17, 2, 12, P.shine);
  rect(image, 2, 20, 3, 7, P.outline);
  rect(image, 3, 21, 2, 5, FREEZE.main);
  setPixel(image, 3, 21, FREEZE.light);
  rect(image, 18, 20, 3, 7, P.outline);
  rect(image, 18, 21, 2, 5, FREEZE.main);
  setPixel(image, 19, 21, P.shine);

  rows(image, 33, [[8, 7], [8, 7], [8, 7], [8, 7], [9, 5],
    [9, 5], [10, 3]], P.outline);
  rect(image, 9, 34, 5, 4, P.panel);
  rect(image, 10, 34, 2, 1, P.lightMetal);

  stampCore(image, 11, 25, FREEZE);
  return {
    name: "glacier_projector_v3",
    image,
    core: [11, 25],
    attack_bbox: [1, 0, 21, 16],
    attribute: "freeze",
  };
}

function visibleColors(image) {
  const colors = new Set();
  for (let offset = 0; offset < image.pixels.length; offset += 4) {
    if (image.pixels[offset + 3] !== 0) {
      colors.add(`${image.pixels[offset]},${image.pixels[offset + 1]},${image.pixels[offset + 2]}`);
    }
  }
  return colors.size;
}

async function saveSample(sample) {
  const input = {
    raw: { width: sample.image.width, height: sample.image.height, channels: 4 },
  };
  await sharp(sample.image.pixels, input)
    .png({ palette: true, colours: 16 })
    .toFile(path.join(OUTPUT_DIR, `${sample.name}.png`));
  await sharp(sample.image.pixels, input)
    .resize(sample.image.width * 12, HEIGHT * 12, { kernel: "nearest" })
    .png()
    .toFile(path.join(OUTPUT_DIR, `${sample.name}_preview.png`));
}

async function buildContactSheet(samples) {
  const panelWidth = 360;
  const panelHeight = 540;
  const composites = [];
  for (let index = 0; index < samples.length; index += 1) {
    const sample = samples[index];
    const sprite = await sharp(sample.image.pixels, {
      raw: { width: sample.image.width, height: HEIGHT, channels: 4 },
    }).resize(sample.image.width * 12, HEIGHT * 12, { kernel: "nearest" }).png().toBuffer();
    composites.push({
      input: sprite,
      left: index * panelWidth + Math.floor((panelWidth - sample.image.width * 12) / 2),
      top: 42,
    });
    composites.push({
      input: Buffer.from(
        `<svg width="${panelWidth}" height="34"><style>text{font:18px sans-serif;fill:#e9f2f2}</style>`
        + `<text x="10" y="24">${sample.name}</text></svg>`
      ),
      left: index * panelWidth,
      top: 0,
    });
  }
  await sharp({
    create: {
      width: panelWidth * samples.length,
      height: panelHeight,
      channels: 4,
      background: { r: 13, g: 22, b: 31, alpha: 1 },
    },
  }).composite(composites).png().toFile(path.join(OUTPUT_DIR, "redesign_samples_v3.png"));
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const samples = [drawMachineGun(), drawDashBlade(), drawGlacierProjector()];
  const manifest = [];
  for (const sample of samples) {
    const colors = visibleColors(sample.image);
    if (colors > MAX_COLORS) throw new Error(`${sample.name}: ${colors} colors`);
    await saveSample(sample);
    manifest.push({
      file: `${sample.name}.png`,
      width: sample.image.width,
      height: sample.image.height,
      visible_colors: colors,
      crystal_core: sample.core,
      core_pattern: CORE_PATTERN,
      attack_bbox: sample.attack_bbox,
      attribute: sample.attribute,
      status: "awaiting_user_approval",
    });
  }
  await buildContactSheet(samples);
  fs.writeFileSync(
    path.join(OUTPUT_DIR, "manifest.json"),
    `${JSON.stringify({ schema_version: 2, max_colors: MAX_COLORS, samples: manifest }, null, 2)}\n`
  );
  process.stdout.write(`${OUTPUT_DIR}\n`);
}

await main();
