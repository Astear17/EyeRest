import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const size = 1024;
const samples = 4;
const center = size / 2;
const eyeLeft = 134;
const eyeRight = 890;
const eyeControlTop = 0;
const eyeControlBottom = 1024;
const artworkWidth = 61;
const irisRadius = 178;
const minuteEnd = [512, 397];
const hourEnd = [608, 576];
const outputDirectory = join(dirname(fileURLToPath(import.meta.url)), '..', 'EyeRest', 'Assets.xcassets', 'AppIcon.appiconset');

const variants = [
  { file: 'AppIcon.png', top: [23, 33, 29], bottom: [16, 23, 25], artwork: [201, 255, 112], glow: true },
  { file: 'AppIcon-Dark.png', top: [11, 16, 14], bottom: [11, 16, 14], artwork: [201, 255, 112], glow: true },
  { file: 'AppIcon-Tinted.png', top: [0, 0, 0], bottom: [0, 0, 0], artwork: [255, 255, 255], glow: false }
];

function pointOnEye(t, controlY) {
  const inverse = 1 - t;
  return [
    inverse * inverse * eyeLeft + 2 * inverse * t * center + t * t * eyeRight,
    inverse * inverse * center + 2 * inverse * t * controlY + t * t * center
  ];
}

function distanceToSegment(x, y, start, end) {
  const deltaX = end[0] - start[0];
  const deltaY = end[1] - start[1];
  const lengthSquared = deltaX * deltaX + deltaY * deltaY;
  const projection = lengthSquared === 0 ? 0 : Math.max(0, Math.min(1, ((x - start[0]) * deltaX + (y - start[1]) * deltaY) / lengthSquared));
  return Math.hypot(x - (start[0] + projection * deltaX), y - (start[1] + projection * deltaY));
}

function distanceToEyeCurve(x, y, controlY) {
  const approximate = Math.max(0, Math.min(1, (x - eyeLeft) / (eyeRight - eyeLeft)));
  const before = Math.max(0, approximate - 0.025);
  const after = Math.min(1, approximate + 0.025);
  return distanceToSegment(x, y, pointOnEye(before, controlY), pointOnEye(after, controlY));
}

function isArtwork(x, y) {
  const halfWidth = artworkWidth / 2;
  if (distanceToEyeCurve(x, y, eyeControlTop) <= halfWidth) return true;
  if (distanceToEyeCurve(x, y, eyeControlBottom) <= halfWidth) return true;
  if (Math.abs(Math.hypot(x - center, y - center) - irisRadius) <= halfWidth) return true;
  if (distanceToSegment(x, y, [center, center], minuteEnd) <= halfWidth) return true;
  if (distanceToSegment(x, y, [center, center], hourEnd) <= halfWidth) return true;
  return false;
}

const coverage = new Uint8Array(size * size);
for (let y = 0; y < size; y += 1) {
  for (let x = 0; x < size; x += 1) {
    let coveredSamples = 0;
    for (let sampleY = 0; sampleY < samples; sampleY += 1) {
      for (let sampleX = 0; sampleX < samples; sampleX += 1) {
        const samplePointX = x + (sampleX + 0.5) / samples;
        const samplePointY = y + (sampleY + 0.5) / samples;
        if (isArtwork(samplePointX, samplePointY)) coveredSamples += 1;
      }
    }
    coverage[y * size + x] = Math.round(coveredSamples / (samples * samples) * 255);
  }
}

const crcTable = Array.from({ length: 256 }, (_, value) => {
  let crc = value;
  for (let bit = 0; bit < 8; bit += 1) crc = (crc & 1) ? 0xedb88320 ^ (crc >>> 1) : crc >>> 1;
  return crc >>> 0;
});

function crc32(data) {
  let crc = 0xffffffff;
  for (const byte of data) crc = crcTable[(crc ^ byte) & 0xff] ^ (crc >>> 8);
  return (crc ^ 0xffffffff) >>> 0;
}

function chunk(type, data) {
  const name = Buffer.from(type, 'ascii');
  const length = Buffer.alloc(4);
  length.writeUInt32BE(data.length);
  const checksum = Buffer.alloc(4);
  checksum.writeUInt32BE(crc32(Buffer.concat([name, data])));
  return Buffer.concat([length, name, data, checksum]);
}

function encodeRGB(width, height, rgb) {
  const stride = 1 + width * 3;
  const scanlines = Buffer.alloc(stride * height);
  for (let y = 0; y < height; y += 1) {
    const row = y * stride;
    scanlines[row] = 0;
    rgb.copy(scanlines, row + 1, y * width * 3, (y + 1) * width * 3);
  }
  const header = Buffer.alloc(13);
  header.writeUInt32BE(width, 0);
  header.writeUInt32BE(height, 4);
  header[8] = 8;
  header[9] = 2;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(scanlines, { level: 9 })),
    chunk('IEND', Buffer.alloc(0))
  ]);
}

function mix(from, to, amount) {
  return from + (to - from) * amount;
}

function renderRGB(variant) {
  const rgb = Buffer.alloc(size * size * 3);
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      const shapeCoverage = coverage[y * size + x] / 255;
      const glowStrength = variant.glow ? Math.max(0, 1 - Math.hypot(x + 0.5 - center, y + 0.5 - center) / 390) * 0.12 : 0;
      const vertical = (y + 0.5) / size;
      const offset = (y * size + x) * 3;
      for (let channel = 0; channel < 3; channel += 1) {
        const base = mix(variant.top[channel], variant.bottom[channel], vertical);
        const glowing = mix(base, variant.artwork[channel], glowStrength);
        rgb[offset + channel] = Math.round(mix(glowing, variant.artwork[channel], shapeCoverage));
      }
    }
  }
  return rgb;
}

function downscale(rgb, targetSize) {
  const output = Buffer.alloc(targetSize * targetSize * 3);
  for (let targetY = 0; targetY < targetSize; targetY += 1) {
    const sourceYStart = Math.floor(targetY * size / targetSize);
    const sourceYEnd = Math.max(sourceYStart + 1, Math.floor((targetY + 1) * size / targetSize));
    for (let targetX = 0; targetX < targetSize; targetX += 1) {
      const sourceXStart = Math.floor(targetX * size / targetSize);
      const sourceXEnd = Math.max(sourceXStart + 1, Math.floor((targetX + 1) * size / targetSize));
      const sums = [0, 0, 0];
      let count = 0;
      for (let sourceY = sourceYStart; sourceY < sourceYEnd; sourceY += 1) {
        for (let sourceX = sourceXStart; sourceX < sourceXEnd; sourceX += 1) {
          const sourceOffset = (sourceY * size + sourceX) * 3;
          for (let channel = 0; channel < 3; channel += 1) sums[channel] += rgb[sourceOffset + channel];
          count += 1;
        }
      }
      const targetOffset = (targetY * targetSize + targetX) * 3;
      for (let channel = 0; channel < 3; channel += 1) output[targetOffset + channel] = Math.round(sums[channel] / count);
    }
  }
  return output;
}

mkdirSync(outputDirectory, { recursive: true });
const previewDirectory = join(dirname(fileURLToPath(import.meta.url)), '..', '.ai', 'previews', 'app-icon');
mkdirSync(previewDirectory, { recursive: true });
for (const variant of variants) {
  const rgb = renderRGB(variant);
  writeFileSync(join(outputDirectory, variant.file), encodeRGB(size, size, rgb));
  if (variant.file === 'AppIcon.png') {
    for (const previewSize of [180, 120, 60, 29]) {
      const preview = downscale(rgb, previewSize);
      writeFileSync(join(previewDirectory, `AppIcon-${previewSize}.png`), encodeRGB(previewSize, previewSize, preview));
    }
  }
}
console.log(`Generated ${variants.length} opaque ${size}x${size} RGB eye-clock app icons and four local small-size previews.`);
