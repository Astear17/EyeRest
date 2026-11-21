import { existsSync, readFileSync } from 'node:fs';
import { dirname, join, normalize } from 'node:path';

const root = 'website';
const pages = ['index.html', 'install.html', 'privacy.html', 'terms.html', '404.html'];
const required = [
  ...pages,
  'assets/styles.css', 'assets/main.js', 'assets/favicon.svg', 'assets/apple-touch-icon.png', 'assets/og-image.png',
  'assets/fonts/dm-sans-latin.woff2', 'assets/fonts/dm-sans-latin-ext.woff2',
  'assets/fonts/instrument-serif-latin.woff2', 'assets/fonts/instrument-serif-italic-latin.woff2',
  'assets/licenses/DM-Sans-OFL.txt', 'assets/licenses/Instrument-Serif-OFL.txt',
  'sitemap.xml', 'robots.txt', 'README.md'
];
for (const file of required) if (!existsSync(join(root, file))) throw new Error(`Missing website file: ${file}`);

const pageSources = new Map(pages.map((page) => [page, readFileSync(join(root, page), 'utf8')]));
const localReferencePattern = /<(a|link|script|img)\b[^>]*?\b(href|src)="([^"]+)"[^>]*>/gi;
for (const [page, html] of pageSources) {
  for (const expected of ['<html lang="en">', '<title>', 'name="description"', 'rel="canonical"', 'property="og:title"', 'property="og:description"', 'property="og:url"', 'property="og:image"', 'name="twitter:card"', 'name="twitter:title"', 'name="twitter:description"', 'name="twitter:image"']) {
    if (!html.includes(expected)) throw new Error(`${page} is missing metadata: ${expected}`);
  }
  if (html.indexOf('localStorage.getItem("eyerest-theme")') > html.indexOf('rel="stylesheet"')) throw new Error(`${page} does not set the theme before loading CSS.`);
  for (const match of html.matchAll(localReferencePattern)) {
    const [tag, element, , value] = match;
    if (value.startsWith('#') || value.startsWith('mailto:') || value.startsWith('tel:')) continue;
    if (/^https?:\/\//.test(value)) {
      if (element === 'a' || (element === 'link' && /rel="canonical"/.test(tag))) continue;
      throw new Error(`${page} makes an external resource request: ${value}`);
    }
    const clean = value.split(/[?#]/)[0];
    if (!clean) continue;
    const resolved = normalize(join(root, dirname(page), clean));
    if (!resolved.startsWith(normalize(root)) || !existsSync(resolved)) throw new Error(`${page} has a broken ${element} reference: ${value}`);
  }
}

const sitemap = readFileSync(join(root, 'sitemap.xml'), 'utf8');
const sitemapURLs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map((match) => match[1]).sort();
const expectedURLs = ['https://astear17.sino.tw/EyeRest/', 'https://astear17.sino.tw/EyeRest/install.html', 'https://astear17.sino.tw/EyeRest/privacy.html', 'https://astear17.sino.tw/EyeRest/terms.html'].sort();
if (JSON.stringify(sitemapURLs) !== JSON.stringify(expectedURLs)) throw new Error('Sitemap pages do not match the public page set.');

function assertPNG(path, width, height) {
  const data = readFileSync(path);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (!data.subarray(0, 8).equals(signature)) throw new Error(`${path} is not a PNG.`);
  if (data.readUInt32BE(16) !== width || data.readUInt32BE(20) !== height) throw new Error(`${path} must be ${width}x${height}.`);
}
assertPNG(join(root, 'assets/apple-touch-icon.png'), 180, 180);
assertPNG(join(root, 'assets/og-image.png'), 1200, 630);

function luminance(hex) {
  const channels = [1, 3, 5].map((index) => Number.parseInt(hex.slice(index, index + 2), 16) / 255).map((value) => value <= 0.04045 ? value / 12.92 : ((value + 0.055) / 1.055) ** 2.4);
  return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2];
}
function contrast(first, second) {
  const values = [luminance(first), luminance(second)].sort((a, b) => b - a);
  return (values[0] + 0.05) / (values[1] + 0.05);
}
for (const [name, foreground, background] of [
  ['dark ink', '#f3f6ef', '#101719'], ['dark muted', '#b5c0b6', '#101719'], ['dark faint', '#94a198', '#101719'],
  ['light ink', '#16221d', '#f5f6f1'], ['light muted', '#4d5d54', '#f5f6f1'], ['light faint', '#5e6e65', '#f5f6f1'], ['lime button', '#16221d', '#dfffaa']
]) {
  const ratio = contrast(foreground, background);
  if (ratio < 4.5) throw new Error(`${name} contrast is ${ratio.toFixed(2)}:1, below 4.5:1.`);
  console.log(`${name} contrast: ${ratio.toFixed(2)}:1`);
}

const allHTML = [...pageSources.values()].join('\n');
for (const stale of ['Natural blinking', 'not available to install', 'macOS/Xcode development', 'Look into the distance for 30 seconds.']) if (allHTML.includes(stale)) throw new Error(`Stale website wording remains: ${stale}`);
const install = pageSources.get('install.html');
for (const expected of ['Feather', 'KSign', 'Sideloadly', 'AltStore', 'Not yet tested', 'Developer Mode', 'about seven days', 'SHA-256', 'first EyeRest release has not been published yet', 'data-copy-command']) if (!install.includes(expected)) throw new Error(`Install guide is missing: ${expected}`);
const css = readFileSync(join(root, 'assets/styles.css'), 'utf8');
const script = readFileSync(join(root, 'assets/main.js'), 'utf8');
if (!css.includes(':focus-visible') || !css.includes('prefers-reduced-motion') || !css.includes('@media(max-width:850px)')) throw new Error('Accessibility or mobile CSS is incomplete.');
if (!script.includes('aria-expanded') || !script.includes('data-open') || !script.includes('localStorage') || !script.includes('navigator.clipboard')) throw new Error('Theme, mobile navigation, or copy behavior is incomplete.');
if (!pageSources.get('index.html').includes('aria-label="Illustration of EyeRest')) throw new Error('The app mockup is not labelled as an illustration.');
console.log(`Website verification passed for ${pages.length} HTML pages and ${required.length} required files.`);
