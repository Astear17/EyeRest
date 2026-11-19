# EyeRest

**A calmer way to build healthier screen habits.**

EyeRest is an offline-first iOS wellness reminder designed to help you take regular breaks, rest your eyes, stay hydrated, and maintain healthier daily habits.

Built with SwiftUI, EyeRest prioritizes simplicity, privacy, and a distraction-free experience. No accounts, advertising, tracking, or cloud dependency.

> **Status:** In development. The iOS application has not yet been validated on a physical device.

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

This checks repository structure, website assets, GitHub Pages configuration, selected iOS project settings, and potentially sensitive committed files.

It does not replace an actual Xcode build or physical-device testing.

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
