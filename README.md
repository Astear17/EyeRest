# EyeRest

**Give your eyes a moment.**

EyeRest is a native, offline-first iOS 17+ app for gentle wellness reminders and guided breaks. It stores preferences and activity history on the iPhone, has no account, ads, analytics, or app network requests, and uses no third-party runtime dependencies.

## What it does

- Five configurable reminders: eye rest, hydration, blinking, posture, and movement.
- Active days, quiet hours, pause controls, and optional notification snooze.
- Four guided breaks with pause and resume, haptics, Reduce Motion support, and completed-session history.
- Activity streaks, weekly break time, a seven-day chart, and 30-day history.
- Local JSON backup export and validated import with one-use undo.
- English and Vietnamese localization.
- Offline medicine reminders with local Taken, Skipped, and Snoozed history and optional hidden names in notifications.

EyeRest provides general wellness prompts and convenience medicine reminders, not medical advice. Do not rely on it alone for important medication. iOS may delay or suppress notifications because of Focus, notification settings, system policy, or an expired app signature.

## Install on an iPhone

EyeRest is distributed outside the App Store as an **unsigned IPA**. Download `EyeRest-unsigned.ipa` and its `.sha256` file from [GitHub Releases](https://github.com/Astear17/EyeRest/releases/latest), verify the checksum, then sign and install the IPA with a tool and signing profile you trust. You do not need Xcode merely to use an already-built IPA, but the IPA will not run until it is signed.

Free Apple ID signing commonly expires after about seven days and then needs re-signing. A signing tool can change the bundle identifier, which makes iOS treat the result as a separate app; export a backup before changing tools or identifiers.

See [Sideloading EyeRest](docs/SIDELOADING.md) for exact Windows and macOS checksum commands, compatibility limits, and troubleshooting. Signing-tool compatibility has not yet been validated on a physical device.

## Build and validate

The project is SwiftUI with one shared `EyeRest` scheme. No signing material belongs in this repository.

On any machine with Node.js:

```bash
node scripts/verify-repository.mjs
```

On macOS with Xcode 16.4 and Swift 5.9 or newer:

```bash
swift test
xcodebuild -project EyeRest.xcodeproj -scheme EyeRest -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  clean build
```

GitHub Actions runs the repository verifier, Foundation-only tests, unsigned Release build, localization checks, and app-icon checks. Manual workflow runs are dry runs that upload artifacts only. A tag matching `v*` will publish a GitHub Release only after both test and build jobs pass; the repository owner creates tags after physical-device testing.

## Documentation

- [Sideloading and signing](docs/SIDELOADING.md)
- [Architecture and scheduling](docs/ARCHITECTURE.md)
- [Build and distribution](docs/IOS_BUILD.md)
- [Validation status](docs/IOS_VALIDATION.md)
- [Backup data format](docs/DATA_FORMAT.md)
- [Physical-device release checklist](docs/RELEASE_CHECKLIST.md)
- [Changelog](CHANGELOG.md)

The static website lives in `website/` and is deployed through GitHub Pages. Preview it with `python -m http.server 4173 --directory website`.

## Repository layout

```text
EyeRest.xcodeproj/    Xcode project
EyeRest/              App source plus Foundation-only package sources
Tests/                Swift package tests
website/              Static product website
docs/                 Technical and owner documentation
scripts/              Dependency-free verification tools
```

## Privacy

EyeRest makes no app network requests. Reminder settings, preferences, and activity records remain local unless the user explicitly exports a backup. The website has separate privacy information.

Developer: [@Astear17](https://github.com/Astear17) · [Repository](https://github.com/Astear17/EyeRest)
