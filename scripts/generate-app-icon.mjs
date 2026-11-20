import { deflateSync } from 'node:zlib';
import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const size = 1024;
const samples = 4;
const center = size / 2;
const orbitRadius = 235;
const dotRadius = 48;
const dotCenters = Array.from({ length: 8 }, (_, index) => {
  const angle = -Math.PI / 2 + index * Math.PI / 4;
  return [center + Math.cos(angle) * orbitRadius, center + Math.sin(angle) * orbitRadius];
});
const dotCoverage = new Uint8Array(size * size);
for (const [dotX, dotY] of dotCenters) {
  const minimumX = Math.floor(dotX - dotRadius - 1);
  const maximumX = Math.ceil(dotX + dotRadius + 1);
  const minimumY = Math.floor(dotY - dotRadius - 1);
  const maximumY = Math.ceil(dotY + dotRadius + 1);
  for (let y = minimumY; y <= maximumY; y += 1) {
    for (let x = minimumX; x <= maximumX; x += 1) {
      let coveredSamples = 0;
      for (let sampleY = 0; sampleY < samples; sampleY += 1) {
        for (let sampleX = 0; sampleX < samples; sampleX += 1) {
          const samplePointX = x + (sampleX + 0.5) / samples;
          const samplePointY = y + (sampleY + 0.5) / samples;
          if (Math.hypot(samplePointX - dotX, samplePointY - dotY) <= dotRadius) coveredSamples += 1;
        }
      }
      dotCoverage[y * size + x] = Math.max(dotCoverage[y * size + x], Math.round(coveredSamples / (samples * samples) * 255));
    }
  }
}
const outputDirectory = join(dirname(fileURLToPath(import.meta.url)), '..', 'EyeRest', 'Assets.xcassets', 'AppIcon.appiconset');

const variants = [
  { file: 'AppIcon.png', top: [23, 33, 29], bottom: [16, 23, 25], ring: [201, 255, 112], glow: true },
  { file: 'AppIcon-Dark.png', top: [16, 23, 25], bottom: [8, 13, 12], ring: [214, 255, 146], glow: true },
  { file: 'AppIcon-Tinted.png', top: [0, 0, 0], bottom: [0, 0, 0], ring: [255, 255, 255], glow: false }
];

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

function mix(from, to, amount) {
  return from + (to - from) * amount;
}

function render(variant) {
  const stride = 1 + size * 3;
  const scanlines = Buffer.alloc(stride * size);
  for (let y = 0; y < size; y += 1) {
    const row = y * stride;
    scanlines[row] = 0;
    for (let x = 0; x < size; x += 1) {
      const coverage = dotCoverage[y * size + x] / 255;
      const glowStrength = variant.glow ? Math.max(0, 1 - Math.hypot(x + 0.5 - center, y + 0.5 - center) / 390) * 0.12 : 0;
      const vertical = (y + 0.5) / size;
      const offset = row + 1 + x * 3;
      for (let channel = 0; channel < 3; channel += 1) {
        const base = mix(variant.top[channel], variant.bottom[channel], vertical);
        const glowing = mix(base, variant.ring[channel], glowStrength);
        scanlines[offset + channel] = Math.round(mix(glowing, variant.ring[channel], coverage));
      }
    }
  }

  const header = Buffer.alloc(13);
  header.writeUInt32BE(size, 0);
  header.writeUInt32BE(size, 4);
  header[8] = 8;
  header[9] = 2;
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', header),
    chunk('IDAT', deflateSync(scanlines, { level: 9 })),
    chunk('IEND', Buffer.alloc(0))
  ]);
  writeFileSync(join(outputDirectory, variant.file), png);
}

mkdirSync(outputDirectory, { recursive: true });
for (const variant of variants) render(variant);
console.log(`Generated ${variants.length} opaque ${size}x${size} RGB app icons from the original website dotted-circle mark.`);
