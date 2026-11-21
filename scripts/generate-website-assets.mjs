import { deflateSync } from 'node:zlib';
import { writeFileSync } from 'node:fs';

const samples = 4;
const center = 512;
const eyeLeft = 134;
const eyeRight = 890;
const artworkWidth = 61;
const irisRadius = 178;
const minuteEnd = [512, 397];
const hourEnd = [608, 576];

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
  return distanceToSegment(
    x,
    y,
    pointOnEye(Math.max(0, approximate - 0.025), controlY),
    pointOnEye(Math.min(1, approximate + 0.025), controlY)
  );
}

function isArtwork(x, y) {
  const halfWidth = artworkWidth / 2;
  return distanceToEyeCurve(x, y, 0) <= halfWidth
    || distanceToEyeCurve(x, y, 1024) <= halfWidth
    || Math.abs(Math.hypot(x - center, y - center) - irisRadius) <= halfWidth
    || distanceToSegment(x, y, [center, center], minuteEnd) <= halfWidth
    || distanceToSegment(x, y, [center, center], hourEnd) <= halfWidth;
}

function mix(from, to, amount) {
  return from + (to - from) * amount;
}

function renderIcon(size) {
  const rgb = Buffer.alloc(size * size * 3);
  const scale = 1024 / size;
  const top = [23, 33, 29];
  const bottom = [16, 23, 25];
  const artwork = [201, 255, 112];
  for (let y = 0; y < size; y += 1) {
    for (let x = 0; x < size; x += 1) {
      let covered = 0;
      for (let sampleY = 0; sampleY < samples; sampleY += 1) {
        for (let sampleX = 0; sampleX < samples; sampleX += 1) {
          const sourceX = (x + (sampleX + 0.5) / samples) * scale;
          const sourceY = (y + (sampleY + 0.5) / samples) * scale;
          if (isArtwork(sourceX, sourceY)) covered += 1;
        }
      }
      const coverage = covered / (samples * samples);
      const sourceCenterX = (x + 0.5) * scale;
      const sourceCenterY = (y + 0.5) * scale;
      const glow = Math.max(0, 1 - Math.hypot(sourceCenterX - center, sourceCenterY - center) / 390) * 0.12;
      const vertical = (y + 0.5) / size;
      const offset = (y * size + x) * 3;
      for (let channel = 0; channel < 3; channel += 1) {
        const base = mix(top[channel], bottom[channel], vertical);
        const glowing = mix(base, artwork[channel], glow);
        rgb[offset + channel] = Math.round(mix(glowing, artwork[channel], coverage));
      }
    }
  }
  return rgb;
}

function solidImage(width, height, color) {
  const rgb = Buffer.alloc(width * height * 3);
  for (let offset = 0; offset < rgb.length; offset += 3) {
    rgb[offset] = color[0];
    rgb[offset + 1] = color[1];
    rgb[offset + 2] = color[2];
  }
  return rgb;
}

function copyImage(source, sourceSize, target, targetWidth, targetX, targetY) {
  for (let y = 0; y < sourceSize; y += 1) {
    const sourceStart = y * sourceSize * 3;
    const targetStart = ((targetY + y) * targetWidth + targetX) * 3;
    source.copy(target, targetStart, sourceStart, sourceStart + sourceSize * 3);
  }
}

const touchSize = 180;
const touch = renderIcon(touchSize);
writeFileSync('website/assets/apple-touch-icon.png', encodeRGB(touchSize, touchSize, touch));

const ogWidth = 1200;
const ogHeight = 630;
const ogIconSize = 360;
const og = solidImage(ogWidth, ogHeight, [11, 16, 14]);
copyImage(renderIcon(ogIconSize), ogIconSize, og, ogWidth, (ogWidth - ogIconSize) / 2, (ogHeight - ogIconSize) / 2);
writeFileSync('website/assets/og-image.png', encodeRGB(ogWidth, ogHeight, og));

console.log('Generated eye-clock apple-touch-icon.png and og-image.png.');
