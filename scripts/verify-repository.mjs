import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const required = [
  'website/index.html', 'website/assets/styles.css', 'website/assets/main.js',
  'website/assets/fonts/dm-sans-latin.woff2', 'website/assets/fonts/dm-sans-latin-ext.woff2',
  'website/assets/fonts/instrument-serif-latin.woff2', 'website/assets/fonts/instrument-serif-italic-latin.woff2',
  '.github/workflows/pages.yml', 'EyeRest.xcodeproj/project.pbxproj',
  'EyeRest.xcodeproj/xcshareddata/xcschemes/EyeRest.xcscheme',
  '.github/workflows/ios-build.yml',
  'Package.swift',
  'Tests/EyeRestLogicTests/NotificationPlannerTests.swift',
  'Tests/EyeRestLogicTests/PersistenceTests.swift',
  'Tests/EyeRestLogicTests/ActivityLogTests.swift',
  'Tests/EyeRestLogicTests/BackupCodecTests.swift',
  'Tests/EyeRestLogicTests/ScheduleRulesTests.swift',
  'Tests/EyeRestLogicTests/BreakSessionTests.swift',
  'Tests/EyeRestLogicTests/QuietHoursTests.swift',
  'EyeRest/Resources/Localizable.xcstrings',
  'EyeRest/EyeRestApp.swift', 'EyeRest/Services/NotificationService.swift', 'EyeRest/Services/PersistenceService.swift',
  'EyeRest/ViewModels/AppViewModel.swift', 'docs/IOS_DEVELOPMENT.md', 'docs/IOS_BUILD.md',
  'docs/RELEASE_CHECKLIST.md',
  'EyeRest/Services/BackupCodec.swift', 'EyeRest/Utilities/BackupDocument.swift', 'docs/DATA_FORMAT.md',
  'EyeRest/Services/ScheduleRules.swift',
  'EyeRest/Models/BreakActivity.swift',
  'EyeRest/Models/BreakSession.swift',
  'Tests/EyeRestLogicTests/BreakActivityTests.swift',
  'EyeRest/Views/ActivityView.swift',
  'EyeRest/Views/WelcomeView.swift',
  'design/source/eye-clock.png', 'design/app-icon.svg', 'scripts/analyze-eye-clock.mjs',
  'scripts/generate-app-icon.mjs', 'EyeRest/Assets.xcassets/Contents.json',
  'EyeRest/Assets.xcassets/AccentColor.colorset/Contents.json', 'EyeRest/Assets.xcassets/AppIcon.appiconset/Contents.json',
  'EyeRest/Assets.xcassets/AppIcon.appiconset/AppIcon.png',
  'EyeRest/Assets.xcassets/AppIcon.appiconset/AppIcon-Dark.png',
  'EyeRest/Assets.xcassets/AppIcon.appiconset/AppIcon-Tinted.png'
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
const stringCatalog = JSON.parse(readFileSync('EyeRest/Resources/Localizable.xcstrings', 'utf8'));

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
if ((pbxproj.match(/ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon/g) ?? []).length !== 2 || (pbxproj.match(/ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor/g) ?? []).length !== 2) throw new Error('Asset catalog build settings are incomplete.');
if (!pbxproj.includes('folder.assetcatalog; path = Assets.xcassets') || !pbxproj.includes('files = (015,016)')) throw new Error('Assets.xcassets is not in the app resources phase.');
if (!scheme.includes('BlueprintIdentifier="300"') || !scheme.includes('BlueprintName="EyeRest"')) throw new Error('Shared EyeRest scheme does not reference the app target.');
if (!infoPlist.includes('<key>CFBundleExecutable</key><string>$(EXECUTABLE_NAME)</string>') || !infoPlist.includes('<key>CFBundlePackageType</key><string>APPL</string>')) throw new Error('Required application bundle metadata is missing.');
for (const expected of ['<key>CFBundleName</key><string>$(PRODUCT_NAME)</string>', '<key>CFBundleInfoDictionaryVersion</key><string>6.0</string>', '<key>CFBundleDevelopmentRegion</key><string>$(DEVELOPMENT_LANGUAGE)</string>', '<key>CFBundleShortVersionString</key><string>$(MARKETING_VERSION)</string>', '<key>CFBundleVersion</key><string>$(CURRENT_PROJECT_VERSION)</string>']) {
  if (!infoPlist.includes(expected)) throw new Error(`Info.plist is missing: ${expected}`);
}
for (const expected of ['name: EyeRest iOS Build', "tags: ['v*']", "'EyeRest/**'", "'Package.swift'", "'Tests/**'", 'runs-on: macos-15', 'Xcode_16.4.app', 'swift test', 'generic/platform=iOS', '-configuration Release', 'CODE_SIGNING_ALLOWED=NO', 'node scripts/verify-repository.mjs', 'CFBundleExecutable', 'CFBundlePackageType', 'CFBundleName', 'CFBundleInfoDictionaryVersion', 'vi.lproj/Localizable.strings', 'en.lproj/Localizable.strings', 'Assets.car', 'CFBundleIcons', 'CFBundleIconName', 'AppIcon60x60', 'cancel-in-progress: true', 'actions/upload-artifact@v4', 'retention-days: 14', 'EyeRest-unsigned.ipa.sha256', 'name: Publish tagged unsigned release', "if: startsWith(github.ref, 'refs/tags/v')", 'contents: write', 'actions/download-artifact@v4', 'actions/github-script@v7', 'createRelease', 'uploadReleaseAsset', 'pull_request:', 'workflow_dispatch:']) {
  if (!iosBuildWorkflow.includes(expected)) throw new Error(`iOS build workflow is missing: ${expected}`);
}
if (stringCatalog.sourceLanguage !== 'en' || stringCatalog.version !== '1.0') throw new Error('String catalog metadata is incorrect.');
for (const [key, value] of Object.entries(stringCatalog.strings)) {
  if (value.localizations?.vi?.stringUnit?.state !== 'translated' || !value.localizations.vi.stringUnit.value) throw new Error(`Missing Vietnamese translation: ${key}`);
  if (value.localizations?.en?.stringUnit?.state !== 'translated' || value.localizations.en.stringUnit.value !== key) throw new Error(`Missing English source localization: ${key}`);
}
for (const key of ['Every %lld min · %@', 'Interval: %lld minutes', '%lld completed', '%lld seconds remaining', '%@ enabled', 'Countdown %@', 'Reminders are queued until %@. Open EyeRest to keep them going.', 'Snooze %lld min', '%u more reminders', '%lld-day streak', '%lld days', '%@ min', '%@: %lld completions', 'Last 7 days: %@', '%lld min', '%lld sec']) {
  if (!stringCatalog.strings[key]?.localizations?.vi?.stringUnit?.value) throw new Error(`Missing interpolated Vietnamese catalog key: ${key}`);
}
if (!notificationService.includes('timeSensitiveSetting') || !notificationService.includes('pendingNotificationRequests')) throw new Error('Expected local-notification scheduling safeguards are missing.');
if (!persistenceService.includes('hasCompletedWelcome = true')) throw new Error('Existing-user welcome migration is missing.');
if (!appViewModel.includes('activityStore.save(activityLog)')) throw new Error('File-backed activity persistence is missing.');

for (const filename of ['AppIcon.png', 'AppIcon-Dark.png', 'AppIcon-Tinted.png']) {
  const path = join('EyeRest', 'Assets.xcassets', 'AppIcon.appiconset', filename);
  const png = readFileSync(path);
  const signature = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  if (!png.subarray(0, 8).equals(signature)) throw new Error(`${filename} is not a PNG.`);
  if (png.readUInt32BE(16) !== 1024 || png.readUInt32BE(20) !== 1024) throw new Error(`${filename} must be 1024x1024.`);
  if (png[24] !== 8 || png[25] !== 2) throw new Error(`${filename} must be 8-bit opaque RGB without alpha.`);
}

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
