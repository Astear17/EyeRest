import { existsSync, readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

const required = [
  'website/index.html', 'website/assets/styles.css', 'website/assets/main.js',
  '.github/workflows/pages.yml', 'ios/EyeRest.xcodeproj/project.pbxproj',
  'ios/EyeRest/EyeRestApp.swift', 'ios/EyeRest/Services/NotificationService.swift',
  'ios/EyeRest/ViewModels/AppViewModel.swift', 'docs/IOS_DEVELOPMENT.md'
];
for (const path of required) if (!existsSync(path)) throw new Error(`Missing required file: ${path}`);

const website = readFileSync('website/index.html', 'utf8');
const css = readFileSync('website/assets/styles.css', 'utf8');
const workflow = readFileSync('.github/workflows/pages.yml', 'utf8');
const pbxproj = readFileSync('ios/EyeRest.xcodeproj/project.pbxproj', 'utf8');
const notificationService = readFileSync('ios/EyeRest/Services/NotificationService.swift', 'utf8');
const appViewModel = readFileSync('ios/EyeRest/ViewModels/AppViewModel.swift', 'utf8');

if (!website.includes('assets/styles.css') || !website.includes('assets/main.js')) throw new Error('Website asset paths are incomplete.');
if (website.includes('fonts.googleapis.com') || website.includes('fonts.gstatic.com')) throw new Error('Website must not load third-party fonts.');
if ((css.match(/{/g) ?? []).length !== (css.match(/}/g) ?? []).length) throw new Error('CSS braces are unbalanced.');
if (!workflow.includes('path: website')) throw new Error('Pages workflow must publish website/.');
if (!pbxproj.includes('PRODUCT_BUNDLE_IDENTIFIER = com.astear17.eyerest') || !pbxproj.includes('IPHONEOS_DEPLOYMENT_TARGET = 17.0')) throw new Error('iOS project settings are incorrect.');
if (!notificationService.includes('timeSensitive') || !notificationService.includes('pendingNotificationRequests')) throw new Error('Expected local-notification scheduling safeguards are missing.');
if (!appViewModel.includes('guard !preferences.isPaused')) throw new Error('Paused-state presentation guard is missing.');

function walk(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    if (entry.name === '.git') return [];
    const path = join(directory, entry.name);
    return entry.isDirectory() ? walk(path) : [path];
  });
}
const suspect = walk('.').filter((path) => /(^|[\\/])(\.env|.*\.pem|.*\.p12|.*\.mobileprovision)$/i.test(path));
if (suspect.length) throw new Error(`Potential secret or signing files found: ${suspect.join(', ')}`);

console.log('Repository static verification passed. Xcode compilation requires macOS.');
