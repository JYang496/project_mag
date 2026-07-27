import { createRequire } from "node:module";
import fs from "node:fs";
import path from "node:path";

const require = createRequire(import.meta.url);
const sharp = require("sharp");

const HEIGHT = 40;
const MAX_COLORS = 12;
const OUTPUT_DIR = path.resolve(
  process.argv[2] ?? "asset/images/weapons/redesign_samples_v2"
);

const P = Object.freeze({
  outline: [5, 18, 31, 255],
  deep: [13, 37, 51, 255],
  gunmetal: [43, 67, 78, 255],
  panel: [82, 107, 116, 255],
  lightMetal: [145, 171, 177, 255],
  armorShade: [190, 207, 207, 255],
  armor: [232, 240, 235, 255],
  shine: [255, 255, 245, 255],
  warning: [218, 61, 45, 255],
});

const KINETIC = Object.freeze({
  dark: [152, 67, 28, 255],
  main: [239, 137, 18, 255],
  light: [255, 220, 79, 255],
});

const FREEZE = Object.freeze({
  dark: [35, 83, 184, 255],
  main: [43, 197, 230, 255],
  light: [184, 247, 255, 255],
});

function createImage(width) {
  return {
    width,
    height: HEIGHT,
    pixels: Buffer.alloc(width * HEIGHT * 4, 0),
  };
}

function setPixel(image, x, y, color) {
  if (x < 0 || y < 0 || x >= image.width || y >= image.height) return;
  const offset = (y * image.width + x) * 4;
  image.pixels[offset] = color[0];
  image.pixels[offset + 1] = color[1];
  image.pixels[offset + 2] = color[2];
  image.pixels[offset + 3] = color[3];
}

function rect(image, x, y, width, height, color) {
  for (let py = y; py < y + height; py += 1) {
    for (let px = x; px < x + width; px += 1) setPixel(image, px, py, color);
  }
}

function rows(image, startY, definitions, color) {
  definitions.forEach(([x, width], index) => {
    rect(image, x, startY + index, width, 1, color);
  });
}

function facetedCrystal(image, centerX, centerY, accent) {
  rows(image, centerY - 3, [
    [centerX - 1, 3],
    [centerX - 2, 5],
    [centerX - 3, 7],
    [centerX - 3, 7],
    [centerX - 3, 7],
    [centerX - 2, 5],
    [centerX - 1, 3],
  ], P.outline);
  rows(image, centerY - 2, [
    [centerX - 1, 3],
    [centerX - 2, 5],
    [centerX - 2, 5],
    [centerX - 2, 5],
    [centerX - 1, 3],
  ], accent.dark);
  rows(image, centerY - 1, [
    [centerX - 1, 3],
    [centerX - 1, 3],
    [centerX - 1, 3],
  ], accent.main);
  setPixel(image, centerX - 1, centerY - 1, accent.light);
  setPixel(image, centerX, centerY - 1, P.shine);
  setPixel(image, centerX - 1, centerY, accent.light);
}

function drawMachineGun() {
  const image = createImage(24);

  // Heavy main barrel with a separate offset stabilizer.
  rows(image, 0, [[8, 7], [7, 9], [7, 9], [6, 10], [6, 10], [6, 10],
    [7, 9], [7, 9], [7, 9], [7, 9], [7, 9], [7, 9]], P.outline);
  rect(image, 8, 1, 6, 10, P.gunmetal);
  rect(image, 9, 1, 2, 9, P.lightMetal);
  rect(image, 12, 2, 1, 7, P.deep);
  rect(image, 8, 4, 6, 1, P.panel);
  rect(image, 8, 8, 6, 1, P.panel);
  rect(image, 17, 5, 4, 12, P.outline);
  rect(image, 18, 6, 2, 10, P.gunmetal);
  setPixel(image, 18, 7, P.lightMetal);
  rect(image, 17, 10, 4, 2, P.panel);
  setPixel(image, 19, 14, KINETIC.main);

  // Left cooling shroud: tall, angular, and deliberately asymmetric.
  rows(image, 10, [[3, 5], [2, 7], [1, 8], [1, 8], [0, 9], [0, 9],
    [0, 9], [0, 9], [0, 9], [0, 9], [0, 9], [0, 9], [1, 8],
    [1, 8], [2, 7], [2, 7], [3, 6], [3, 6], [4, 5], [4, 5]], P.outline);
  rows(image, 12, [[4, 3], [3, 4], [2, 5], [2, 5], [2, 5], [2, 5],
    [2, 5], [2, 5], [2, 5], [2, 5], [3, 4], [3, 4], [4, 3],
    [4, 3], [5, 2]], P.armor);
  rect(image, 2, 15, 2, 10, P.armorShade);
  rect(image, 5, 14, 2, 12, P.shine);
  rect(image, 1, 18, 2, 1, P.warning);
  rect(image, 1, 21, 3, 1, P.panel);
  rect(image, 2, 24, 2, 1, KINETIC.main);

  // Central receiver with inset mechanical rails.
  rows(image, 10, [[8, 10], [7, 11], [7, 11], [6, 12], [6, 12], [6, 12],
    [6, 12], [6, 12], [6, 12], [6, 12], [6, 12], [6, 12], [6, 12],
    [6, 12], [6, 12], [6, 12], [6, 12], [7, 11], [7, 11],
    [8, 10], [8, 10], [8, 10], [9, 8]], P.outline);
  rect(image, 8, 12, 8, 18, P.deep);
  rect(image, 9, 13, 2, 15, P.gunmetal);
  rect(image, 13, 13, 2, 15, P.panel);
  rect(image, 10, 14, 4, 1, P.lightMetal);
  rect(image, 10, 17, 4, 1, KINETIC.dark);
  rect(image, 10, 27, 4, 2, P.gunmetal);

  // Curved ammunition rotor on the right.
  rows(image, 17, [[17, 5], [16, 7], [15, 9], [15, 9], [15, 9],
    [14, 10], [14, 10], [14, 10], [14, 10], [14, 10], [14, 10],
    [15, 9], [15, 9], [16, 8], [16, 7], [17, 6]], P.outline);
  rows(image, 19, [[18, 3], [17, 5], [17, 5], [16, 6], [16, 6],
    [16, 6], [16, 6], [16, 6], [17, 5], [17, 5], [18, 3]], P.gunmetal);
  setPixel(image, 19, 20, KINETIC.light);
  setPixel(image, 20, 22, KINETIC.main);
  setPixel(image, 20, 25, KINETIC.light);
  setPixel(image, 19, 28, KINETIC.main);
  rect(image, 16, 23, 2, 4, P.deep);

  // Large identity core and compact rear grip.
  facetedCrystal(image, 11, 23, KINETIC);
  rows(image, 30, [[8, 8], [8, 8], [9, 6], [9, 6], [9, 6],
    [9, 6], [9, 6], [8, 8], [8, 8], [9, 6]], P.outline);
  rect(image, 10, 31, 4, 6, P.gunmetal);
  rect(image, 11, 32, 2, 1, P.lightMetal);
  rect(image, 11, 35, 2, 1, KINETIC.main);
  rect(image, 9, 38, 6, 1, P.armorShade);

  return { name: "machine_gun_v2", image, core: [11, 23], attribute: "kinetic" };
}

function drawDashBlade() {
  const image = createImage(26);

  // A short central blade carried by two large swept armor wings.
  rows(image, 0, [[12, 2], [11, 4], [10, 6], [10, 6], [9, 8],
    [9, 8], [9, 8], [9, 8], [10, 6], [10, 6], [10, 6],
    [11, 4], [11, 4], [11, 4], [11, 4], [11, 4], [11, 4]], P.outline);
  rows(image, 2, [[12, 2], [11, 4], [11, 4], [10, 6], [10, 6],
    [10, 6], [10, 6], [11, 4], [11, 4], [11, 4], [12, 2],
    [12, 2]], FREEZE.main);
  rect(image, 12, 2, 2, 10, FREEZE.light);
  rect(image, 14, 5, 1, 8, FREEZE.dark);
  setPixel(image, 12, 3, P.shine);

  rows(image, 4, [[3, 4], [2, 6], [2, 6], [1, 7], [1, 7], [1, 8],
    [1, 8], [1, 8], [1, 9], [1, 9], [2, 9], [2, 9], [2, 9],
    [3, 9], [3, 9], [3, 9], [4, 9], [4, 9], [5, 8]], P.outline);
  rows(image, 4, [[19, 4], [18, 6], [18, 6], [18, 7], [18, 7], [17, 8],
    [17, 8], [17, 8], [16, 9], [16, 9], [15, 9], [15, 9], [15, 9],
    [14, 9], [14, 9], [14, 9], [13, 9], [13, 9], [13, 8]], P.outline);
  rows(image, 6, [[4, 2], [3, 4], [3, 4], [2, 5], [2, 5],
    [2, 6], [2, 6], [2, 6], [3, 6], [3, 6], [3, 6],
    [4, 6], [4, 6], [5, 5], [5, 5]], P.armor);
  rows(image, 6, [[20, 2], [19, 4], [19, 4], [19, 5], [19, 5],
    [18, 6], [18, 6], [18, 6], [17, 6], [17, 6], [17, 6],
    [16, 6], [16, 6], [16, 5], [16, 5]], P.armor);
  rows(image, 8, [[3, 2], [3, 2], [3, 2], [3, 2], [3, 2],
    [4, 2], [4, 2], [5, 2], [5, 2], [6, 2]], P.shine);
  rows(image, 8, [[21, 2], [21, 2], [21, 2], [21, 2], [21, 2],
    [20, 2], [20, 2], [19, 2], [19, 2], [18, 2]], P.armorShade);
  rect(image, 5, 14, 3, 1, P.panel);
  rect(image, 18, 14, 3, 1, P.panel);
  rect(image, 6, 18, 3, 1, FREEZE.main);
  rect(image, 17, 18, 3, 1, FREEZE.main);

  // Dark blade spine and ring socket.
  rows(image, 14, [[9, 8], [8, 10], [8, 10], [7, 12], [7, 12],
    [7, 12], [7, 12], [7, 12], [7, 12], [7, 12], [7, 12],
    [8, 10], [8, 10], [9, 8], [9, 8]], P.outline);
  rect(image, 10, 15, 6, 14, P.deep);
  rect(image, 11, 15, 2, 10, P.gunmetal);
  rect(image, 14, 16, 1, 9, P.panel);
  facetedCrystal(image, 12, 23, FREEZE);

  // Asymmetric dash booster on the lower right.
  rows(image, 25, [[18, 4], [18, 5], [18, 6], [18, 7], [18, 7],
    [18, 7], [18, 7], [18, 7], [19, 6], [19, 6], [20, 5], [21, 4]], P.outline);
  rows(image, 27, [[20, 2], [19, 4], [19, 4], [19, 4], [19, 4],
    [20, 3], [20, 3], [21, 2]], P.armor);
  rect(image, 20, 29, 2, 1, P.shine);
  rect(image, 21, 32, 2, 1, FREEZE.main);
  rect(image, 22, 34, 1, 1, FREEZE.dark);

  // Compact grip and faceted pommel.
  rows(image, 28, [[9, 8], [9, 8], [10, 6], [10, 6], [10, 6],
    [10, 6], [10, 6], [10, 6], [9, 8], [9, 8], [10, 6], [11, 4]], P.outline);
  rect(image, 11, 29, 4, 8, P.gunmetal);
  rect(image, 12, 30, 2, 1, P.lightMetal);
  rect(image, 12, 33, 2, 1, P.panel);
  rect(image, 10, 36, 6, 2, P.armorShade);
  setPixel(image, 12, 37, FREEZE.main);
  setPixel(image, 13, 37, FREEZE.main);

  return { name: "dash_blade_v2", image, core: [12, 23], attribute: "energy" };
}

function drawGlacierProjector() {
  const image = createImage(28);

  // Three independent emitter prongs.
  rows(image, 0, [[4, 3], [3, 5], [2, 6], [2, 7], [1, 8],
    [1, 8], [1, 9], [2, 8], [2, 8], [3, 7], [3, 7], [4, 6]], P.outline);
  rows(image, 1, [[5, 1], [4, 3], [3, 4], [3, 5], [2, 6],
    [2, 6], [2, 7], [3, 6], [3, 6], [4, 5]], P.armor);
  rows(image, 0, [[21, 3], [20, 5], [20, 6], [19, 7], [19, 8],
    [19, 8], [18, 9], [18, 8], [18, 8], [18, 7], [18, 7], [18, 6]], P.outline);
  rows(image, 1, [[22, 1], [21, 3], [21, 4], [20, 5], [20, 6],
    [20, 6], [19, 7], [19, 6], [19, 6], [19, 5]], P.armor);
  rect(image, 4, 4, 2, 5, P.shine);
  rect(image, 22, 4, 2, 5, P.armorShade);
  setPixel(image, 7, 5, FREEZE.light);
  setPixel(image, 7, 7, FREEZE.main);
  setPixel(image, 20, 5, FREEZE.light);
  setPixel(image, 20, 7, FREEZE.main);
  rows(image, 2, [[12, 4], [11, 6], [11, 6], [10, 8], [10, 8],
    [10, 8], [10, 8], [11, 6], [11, 6]], P.outline);
  rect(image, 12, 3, 4, 7, P.gunmetal);
  rect(image, 13, 4, 2, 5, FREEZE.main);
  setPixel(image, 13, 4, FREEZE.light);

  // Trapezoid insulated body with cooling ribs.
  rows(image, 9, [[7, 14], [6, 16], [5, 18], [4, 20], [4, 20],
    [3, 22], [3, 22], [3, 22], [3, 22], [3, 22], [3, 22],
    [3, 22], [4, 20], [4, 20], [5, 18], [5, 18], [6, 16],
    [6, 16], [7, 14], [7, 14], [8, 12], [8, 12], [9, 10]], P.outline);
  rows(image, 11, [[8, 12], [7, 14], [6, 16], [6, 16], [5, 18],
    [5, 18], [5, 18], [5, 18], [5, 18], [6, 16], [6, 16],
    [7, 14], [7, 14], [8, 12], [8, 12], [9, 10]], P.armor);
  rect(image, 6, 13, 3, 11, P.armorShade);
  rect(image, 19, 13, 3, 11, P.shine);
  rect(image, 10, 11, 8, 4, P.deep);
  rect(image, 11, 12, 2, 2, FREEZE.main);
  rect(image, 15, 12, 2, 2, FREEZE.main);
  rect(image, 9, 16, 10, 2, P.gunmetal);
  rect(image, 10, 16, 1, 2, P.lightMetal);
  rect(image, 13, 16, 1, 2, P.lightMetal);
  rect(image, 16, 16, 1, 2, P.lightMetal);

  // Unequal coolant canisters.
  rows(image, 14, [[0, 5], [0, 6], [0, 6], [0, 7], [0, 7],
    [0, 7], [0, 7], [0, 7], [0, 7], [0, 7], [0, 7], [0, 7],
    [1, 6], [1, 6], [2, 5], [2, 5]], P.outline);
  rect(image, 1, 17, 5, 9, P.gunmetal);
  rect(image, 2, 18, 3, 7, FREEZE.main);
  rect(image, 2, 18, 1, 7, FREEZE.light);
  rect(image, 3, 25, 3, 2, FREEZE.dark);
  rows(image, 17, [[23, 4], [22, 6], [22, 6], [21, 7], [21, 7],
    [21, 7], [21, 7], [21, 7], [21, 7], [22, 6], [22, 6],
    [23, 5], [23, 5]], P.outline);
  rect(image, 23, 20, 4, 7, P.gunmetal);
  rect(image, 24, 21, 2, 5, FREEZE.main);
  setPixel(image, 24, 21, FREEZE.light);

  // Large core, lower radiator, and short grip.
  facetedCrystal(image, 13, 21, FREEZE);
  rect(image, 10, 26, 8, 4, P.deep);
  rect(image, 11, 27, 1, 2, FREEZE.main);
  rect(image, 13, 27, 1, 2, FREEZE.light);
  rect(image, 15, 27, 1, 2, FREEZE.main);
  rows(image, 29, [[8, 12], [8, 12], [9, 10], [9, 10], [9, 10],
    [10, 8], [10, 8], [10, 8], [11, 6], [11, 6], [12, 4]], P.outline);
  rect(image, 10, 30, 8, 4, P.armor);
  rect(image, 11, 30, 6, 1, P.shine);
  rect(image, 12, 34, 4, 5, P.gunmetal);
  rect(image, 13, 35, 2, 1, P.lightMetal);
  rect(image, 13, 37, 2, 1, FREEZE.main);

  return { name: "glacier_projector_v2", image, core: [13, 21], attribute: "freeze" };
}

function visibleColors(image) {
  const colors = new Set();
  for (let offset = 0; offset < image.pixels.length; offset += 4) {
    if (image.pixels[offset + 3] === 0) continue;
    colors.add(
      `${image.pixels[offset]},${image.pixels[offset + 1]},${image.pixels[offset + 2]},${image.pixels[offset + 3]}`
    );
  }
  return colors.size;
}

function pixelAt(image, x, y) {
  const offset = (y * image.width + x) * 4;
  return [
    image.pixels[offset],
    image.pixels[offset + 1],
    image.pixels[offset + 2],
    image.pixels[offset + 3],
  ];
}

function validateSample(sample) {
  const issues = [];
  const colors = visibleColors(sample.image);
  if (sample.image.height !== HEIGHT) issues.push("height is not 40");
  if (colors > MAX_COLORS) issues.push(`${colors} colors exceeds ${MAX_COLORS}`);
  if (pixelAt(sample.image, 0, 0)[3] !== 0) issues.push("top-left corner is opaque");
  const [coreX, coreY] = sample.core;
  const coreCenter = pixelAt(sample.image, coreX, coreY);
  if (coreCenter[3] !== 255) issues.push("crystal core center is transparent");
  if (issues.length > 0) throw new Error(`${sample.name}: ${issues.join(", ")}`);
  return colors;
}

async function saveSample(sample) {
  const rawOptions = {
    raw: {
      width: sample.image.width,
      height: sample.image.height,
      channels: 4,
    },
  };
  await sharp(sample.image.pixels, rawOptions)
    .png({ palette: true, colours: 16 })
    .toFile(path.join(OUTPUT_DIR, `${sample.name}.png`));
  await sharp(sample.image.pixels, rawOptions)
    .resize(sample.image.width * 12, sample.image.height * 12, { kernel: "nearest" })
    .png()
    .toFile(path.join(OUTPUT_DIR, `${sample.name}_preview.png`));
}

async function buildContactSheet(samples) {
  const panelWidth = 380;
  const panelHeight = 540;
  const composites = [];
  for (let index = 0; index < samples.length; index += 1) {
    const sample = samples[index];
    const sprite = await sharp(sample.image.pixels, {
      raw: {
        width: sample.image.width,
        height: sample.image.height,
        channels: 4,
      },
    }).resize(sample.image.width * 12, sample.image.height * 12, {
      kernel: "nearest",
    }).png().toBuffer();
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
  }).composite(composites).png().toFile(path.join(OUTPUT_DIR, "redesign_samples_v2.png"));
}

async function main() {
  fs.mkdirSync(OUTPUT_DIR, { recursive: true });
  const samples = [drawMachineGun(), drawDashBlade(), drawGlacierProjector()];
  const manifest = [];
  for (const sample of samples) {
    const colors = validateSample(sample);
    await saveSample(sample);
    manifest.push({
      file: `${sample.name}.png`,
      width: sample.image.width,
      height: sample.image.height,
      visible_colors: colors,
      crystal_core: sample.core,
      attribute: sample.attribute,
      status: "awaiting_user_approval",
    });
  }
  await buildContactSheet(samples);
  fs.writeFileSync(
    path.join(OUTPUT_DIR, "manifest.json"),
    `${JSON.stringify({ schema_version: 1, max_colors: MAX_COLORS, samples: manifest }, null, 2)}\n`
  );
  process.stdout.write(`${OUTPUT_DIR}\n`);
}

await main();
