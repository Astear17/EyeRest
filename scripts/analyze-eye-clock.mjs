import { readFileSync } from 'node:fs';
import { inflateSync } from 'node:zlib';

const input = process.argv[2] ?? 'design/source/eye-clock.png';
const png = readFileSync(input);
const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
if (!png.subarray(0, 8).equals(signature)) throw new Error(`${input} is not a PNG.`);

let offset = 8;
let header;
const imageData = [];
while (offset < png.length) {
  const length = png.readUInt32BE(offset);
  const type = png.toString('ascii', offset + 4, offset + 8);
  const data = png.subarray(offset + 8, offset + 8 + length);
  if (type === 'IHDR') header = data;
  if (type === 'IDAT') imageData.push(data);
  offset += length + 12;
}
if (!header || imageData.length === 0) throw new Error('PNG is missing IHDR or IDAT data.');

const width = header.readUInt32BE(0);
const height = header.readUInt32BE(4);
const bitDepth = header[8];
const colorType = header[9];
if (bitDepth !== 8 || colorType !== 6) throw new Error('Expected an 8-bit RGBA reference PNG.');

const bytesPerPixel = 4;
const rowBytes = width * bytesPerPixel;
const encoded = inflateSync(Buffer.concat(imageData));
const pixels = Buffer.alloc(rowBytes * height);
const paeth = (a, b, c) => {
  const estimate = a + b - c;
  const distanceA = Math.abs(estimate - a);
  const distanceB = Math.abs(estimate - b);
  const distanceC = Math.abs(estimate - c);
  if (distanceA <= distanceB && distanceA <= distanceC) return a;
  return distanceB <= distanceC ? b : c;
};

for (let y = 0; y < height; y += 1) {
  const encodedRow = y * (rowBytes + 1);
  const outputRow = y * rowBytes;
  const filter = encoded[encodedRow];
  for (let x = 0; x < rowBytes; x += 1) {
    const raw = encoded[encodedRow + 1 + x];
    const left = x >= bytesPerPixel ? pixels[outputRow + x - bytesPerPixel] : 0;
    const above = y > 0 ? pixels[outputRow + x - rowBytes] : 0;
    const upperLeft = y > 0 && x >= bytesPerPixel ? pixels[outputRow + x - rowBytes - bytesPerPixel] : 0;
    let value;
    if (filter === 0) value = raw;
    else if (filter === 1) value = raw + left;
    else if (filter === 2) value = raw + above;
    else if (filter === 3) value = raw + Math.floor((left + above) / 2);
    else if (filter === 4) value = raw + paeth(left, above, upperLeft);
    else throw new Error(`Unsupported PNG filter ${filter}.`);
    pixels[outputRow + x] = value & 0xff;
  }
}

let alphaMinimum = 255;
let alphaMaximum = 0;
let minimumX = width;
let minimumY = height;
let maximumX = -1;
let maximumY = -1;
let foregroundCount = 0;
for (let index = 3; index < pixels.length; index += bytesPerPixel) {
  alphaMinimum = Math.min(alphaMinimum, pixels[index]);
  alphaMaximum = Math.max(alphaMaximum, pixels[index]);
}
const alphaVaries = alphaMinimum !== alphaMaximum;
const isForeground = (x, y) => {
  const index = (y * width + x) * bytesPerPixel;
  const red = pixels[index];
  const green = pixels[index + 1];
  const blue = pixels[index + 2];
  const alpha = pixels[index + 3];
  const distanceFromWhite = Math.hypot(255 - red, 255 - green, 255 - blue);
  return alphaVaries ? alpha > 16 : distanceFromWhite > 28;
};

for (let y = 0; y < height; y += 1) {
  for (let x = 0; x < width; x += 1) {
    const alpha = pixels[(y * width + x) * bytesPerPixel + 3];
    if (!isForeground(x, y)) continue;
    foregroundCount += 1;
    minimumX = Math.min(minimumX, x);
    minimumY = Math.min(minimumY, y);
    maximumX = Math.max(maximumX, x);
    maximumY = Math.max(maximumY, y);
  }
}

const runs = (values) => {
  const result = [];
  let start = null;
  for (let index = 0; index <= values.length; index += 1) {
    if (index < values.length && values[index] && start === null) start = index;
    if ((index === values.length || !values[index]) && start !== null) {
      result.push([start, index - 1, index - start]);
      start = null;
    }
  }
  return result;
};

const centerX = Math.round((minimumX + maximumX) / 2);
const centerY = Math.round((minimumY + maximumY) / 2);
const horizontalRuns = runs(Array.from({ length: width }, (_, x) => isForeground(x, centerY)));
const verticalRuns = runs(Array.from({ length: height }, (_, y) => isForeground(centerX, y)));

console.log(JSON.stringify({
  input,
  width,
  height,
  bitDepth,
  colorType,
  alpha: { minimum: alphaMinimum, maximum: alphaMaximum },
  foreground: {
    method: alphaVaries ? 'alpha greater than 16' : 'RGB distance from white greater than 28',
    pixels: foregroundCount,
    bounds: { minimumX, minimumY, maximumX, maximumY },
    center: { x: centerX, y: centerY },
    horizontalRunsAtCenter: horizontalRuns,
    verticalRunsAtCenter: verticalRuns
  }
}, null, 2));
