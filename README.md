# EyeRest

**A calmer way to build healthier screen habits.**

EyeRest is an offline-first iOS wellness reminder designed to help you take regular breaks, rest your eyes, stay hydrated, and maintain healthier daily habits.

Built with SwiftUI, EyeRest prioritizes simplicity, privacy, and a distraction-free experience. No accounts, advertising, tracking, or cloud dependency.

> [!IMPORTANT]
> I am a meat proxy, so expect bugs when using. This project is built on GPT 5.6 Sol.

## Features

- **Eye relaxation** — Gentle reminders to look into the distance.
- **Hydration** — Reminders to stay hydrated throughout the day.
- **Natural blinking** — Encouragement to blink and relax your eyes.
- **Posture** — Occasional reminders to check your sitting position.
- **Movement** — Encouragement to take regular movement breaks.
- **Offline-first** — Designed to operate without an internet connection.

Feature availability depends on implementation and testing progress.

## Technology

- Swift and SwiftUI
- iOS 17.0+
- UserNotifications for local notifications
- Local persistence
- No third-party runtime dependencies

## Getting started

### Requirements

- macOS with a compatible version of Xcode (15 or newer).
- iOS 17.0+ deployment target.
- An Apple development account for installing signed builds on physical devices.

### Open the project

Clone the repository:

```bash
git clone https://github.com/Astear17/EyeRest.git
cd EyeRest
```

Open the Xcode project:

```bash
open EyeRest.xcodeproj
```

Select your development team and configure signing before installing the application on a physical iPhone.

See [iOS Build Guide](docs/IOS_BUILD.md) and [iOS Validation Guide](docs/IOS_VALIDATION.md) for additional instructions.

## Website

The EyeRest product website is maintained separately in `website/` and deployed through GitHub Pages.

Preview it locally:

```bash
python -m http.server 4173 --directory website
```

Then open:

http://127.0.0.1:4173

## Repository structure

```text
EyeRest/
├── .github/
│   └── workflows/       # GitHub Actions
├── EyeRest/
│   └──                 # SwiftUI application source
├── EyeRest.xcodeproj/   # Xcode project
├── website/             # Product website
├── docs/                # Technical documentation
├── scripts/             # Development and validation scripts
└── README.md
```

## Validation

Run the repository verification script:

```bash
node scripts/verify-repository.mjs
```

This checks repository structure, website assets, GitHub Pages configuration, selected iOS project settings, the iOS build workflow, and potentially sensitive committed files. It does not replace `xcodebuild` or physical-device testing.

## GitHub-hosted iOS builds

Xcode is not required on a local Windows machine to compile EyeRest. The **EyeRest iOS Build** GitHub Actions workflow runs on every push to `main`, every pull request targeting `main`, and when started manually from **Actions → EyeRest iOS Build → Run workflow**. It uses the GitHub-hosted `macos-15` runner and explicitly selects Xcode 16.4.

Each successful run builds the sole shared `EyeRest` scheme in the Release configuration for a generic iOS device with code signing disabled. Open that run’s **Artifacts** section to download `eyerest-ios-unsigned-<commit>` for 14 days. It includes:

- `EyeRest-unsigned.app.zip` — the compiled app bundle for inspection.
- `EyeRest-unsigned.ipa` — an **unsigned**, inspection-only IPA.
- `xcodebuild.log` and `build-metadata.json` — diagnostics plus the commit, version, build number, configuration, SDK, and signing state.

An unsigned IPA cannot be installed on a normal iPhone. Device installation still requires valid Apple signing (for example, a development-signed build exported on macOS or re-signed through an authorized workflow). See [docs/IOS_BUILD.md](docs/IOS_BUILD.md#github-actions-builds) for troubleshooting and the exact CI behavior.

## Privacy

EyeRest is designed around a privacy-first approach:

- No user accounts.
- No advertising.
- No tracking or analytics.
- No cloud dependency.
- Local reminder scheduling and preferences.

## Project

- **Developer:** [@Astear17](https://github.com/Astear17)
- **Repository:** [Astear17/EyeRest](https://github.com/Astear17/EyeRest)
- **Website:** [EyeRest on GitHub Pages](https://astear17.github.io/EyeRest/)

---

*EyeRest — Give your eyes a moment.*
