import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const required = [
  'website/index.html', 'website/assets/styles.css', 'website/assets/main.js',
  'website/assets/fonts/dm-sans-latin.woff2', 'website/assets/fonts/dm-sans-latin-ext.woff2',
  'website/assets/fonts/instrument-serif-latin.woff2', 'website/assets/fonts/instrument-serif-italic-latin.woff2',
  '.github/workflows/pages.yml', 'EyeRest.xcodeproj/project.pbxproj',
  'EyeRest.xcodeproj/xcshareddata/xcschemes/EyeRest.xcscheme',
  '.github/workflows/ios-build.yml',
  'EyeRest/EyeRestApp.swift', 'EyeRest/Services/NotificationService.swift', 'EyeRest/Services/PersistenceService.swift',
  'EyeRest/ViewModels/AppViewModel.swift', 'docs/IOS_DEVELOPMENT.md', 'docs/IOS_BUILD.md'
];
for (const path of required) if (!existsSync(path)) throw new Error(`Missing required file: ${path}`);

const website = readFileSync('website/index.html', 'utf8');
const css = readFileSync('website/assets/styles.css', 'utf8');
const workflow = readFileSync('.github/workflows/pages.yml', 'utf8');
const iosBuildWorkflow = readFileSync('.github/workflows/ios-build.yml', 'utf8');
const pbxproj = readFileSync('EyeRest.xcodeproj/project.pbxproj', 'utf8');
const scheme = readFileSync('EyeRest.xcodeproj/xcshareddata/xcschemes/EyeRest.xcscheme', 'utf8');
const infoPlist = readFileSync('EyeRest/Info.plist', 'utf8');
const notificationService = readFileSync('EyeRest/Services/NotificationService.swift', 'utf8');
const persistenceService = readFileSync('EyeRest/Services/PersistenceService.swift', 'utf8');
const appViewModel = readFileSync('EyeRest/ViewModels/AppViewModel.swift', 'utf8');

function assertBalancedSwiftDelimiters(path) {
  const source = readFileSync(path, 'utf8');
  const pairs = { ')': '(', ']': '[', '}': '{' };
  const stack = [];
  const stringReturnStates = [];
  let state = 'code';
  let blockCommentDepth = 0;
  for (let index = 0; index < source.length; index += 1) {
    const character = source[index];
    const next = source[index + 1];
    if (state === 'lineComment') {
      if (character === '\n') state = 'code';
      continue;
    }
    if (state === 'blockComment') {
      if (character === '/' && next === '*') { blockCommentDepth += 1; index += 1; }
      else if (character === '*' && next === '/') {
        blockCommentDepth -= 1;
        index += 1;
        if (blockCommentDepth === 0) state = 'code';
      }
      continue;
    }
    if (state === 'string') {
      if (character === '\\' && next === '(') {
        stack.push({ character: '(', index, returnState: 'string' });
        state = 'code';
        index += 1;
      } else if (character === '\\') index += 1;
      else if (character === '"') state = stringReturnStates.pop() ?? 'code';
      continue;
    }
    if (character === '/' && next === '/') { state = 'lineComment'; index += 1; continue; }
    if (character === '/' && next === '*') { state = 'blockComment'; blockCommentDepth = 1; index += 1; continue; }
    if (character === '"') { stringReturnStates.push('code'); state = 'string'; continue; }
    if ('([{'.includes(character)) stack.push({ character, index });
    else if (')]}'.includes(character)) {
      const opening = stack.pop();
      if (opening?.character !== pairs[character]) throw new Error(`Unbalanced Swift delimiter in ${path} at character ${index}.`);
      if (opening.returnState) state = opening.returnState;
    }
  }
  if (state === 'blockComment') throw new Error(`Unclosed block comment in ${path}.`);
  if (state === 'string') throw new Error(`Unclosed string literal in ${path}.`);
  if (stack.length) throw new Error(`Unclosed Swift delimiter in ${path} at character ${stack.at(-1).index}.`);
}

if (!website.includes('assets/styles.css') || !website.includes('assets/main.js')) throw new Error('Website asset paths are incomplete.');
if (!css.includes('fonts/dm-sans-latin.woff2') || !css.includes('fonts/dm-sans-latin-ext.woff2') || !css.includes('fonts/instrument-serif-latin.woff2')) throw new Error('Self-hosted website typography resources are missing.');
if ((css.match(/{/g) ?? []).length !== (css.match(/}/g) ?? []).length) throw new Error('CSS braces are unbalanced.');
if (!workflow.includes('path: website') || !workflow.includes("'website/**'")) throw new Error('Pages workflow paths are incorrect.');
if (!workflow.includes('node scripts/verify-website.mjs')) throw new Error('Pages workflow does not verify the static website.');
if (!pbxproj.includes('PRODUCT_BUNDLE_IDENTIFIER = com.astear17.eyerest') || !pbxproj.includes('IPHONEOS_DEPLOYMENT_TARGET = 17.0') || !pbxproj.includes('SWIFT_VERSION = 5.9')) throw new Error('iOS project settings are incorrect.');
if (!scheme.includes('BlueprintIdentifier="300"') || !scheme.includes('BlueprintName="EyeRest"')) throw new Error('Shared EyeRest scheme does not reference the app target.');
if (!infoPlist.includes('<key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>') || !infoPlist.includes('<key>CFBundlePackageType</key><string>APPL</string>')) throw new Error('Required application bundle metadata is missing.');
for (const expected of ['name: EyeRest iOS Build', "'EyeRest/**'", 'runs-on: macos-15', 'Xcode_16.4.app', 'generic/platform=iOS', '-configuration Release', 'CODE_SIGNING_ALLOWED=NO', 'CFBundleExecutable', 'CFBundlePackageType', 'actions/upload-artifact@v4', 'retention-days: 14', 'pull_request:']) {
  if (!iosBuildWorkflow.includes(expected)) throw new Error(`iOS build workflow is missing: ${expected}`);
}
if (!notificationService.includes('timeSensitiveSetting') || !notificationService.includes('pendingNotificationRequests')) throw new Error('Expected local-notification scheduling safeguards are missing.');
if (!persistenceService.includes('Array(completions.suffix(500))')) throw new Error('Completion-history persistence limit is missing.');
if (!appViewModel.includes('guard !preferences.isPaused')) throw new Error('Paused-state presentation guard is missing.');

function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '.git') return [];
    const path = join(directory, entry.name);
    return entry.isDirectory() ? walk(path) : [path];
  });
}
const swiftSources = walk('EyeRest').filter((path) => path.endsWith('.swift'));
for (const path of swiftSources) {
  if (!pbxproj.includes(path.split(/[\\/]/).at(-1))) throw new Error(`Swift source is not referenced by the Xcode project: ${path}`);
  assertBalancedSwiftDelimiters(path);
}
const suspect = walk('.').filter((path) => /(^|[\\/])(\.env|.*\.pem|.*\.p12|.*\.mobileprovision)$/i.test(path));
if (suspect.length) throw new Error(`Potential secret or signing files found: ${suspect.join(', ')}`);

console.log('Repository static verification passed. Xcode compilation requires macOS.');
