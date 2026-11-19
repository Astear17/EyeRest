# EyeRest

EyeRest is a privacy-first, offline wellness reminder project for iPhone. This repository contains the public landing site and the native SwiftUI source in one deliberately small monorepo.

## Repository map

- [`website/`](website/) — dependency-free static landing site deployed with GitHub Pages.
- [`ios/`](ios/) — Xcode project for the planned iOS 17+ app; build it on macOS.
- [`docs/`](docs/) — iOS development and packaging notes.
- [`.ai/docs/design/`](.ai/docs/design/) — engineering design review records.
- [`.github/workflows/pages.yml`](.github/workflows/pages.yml) — Pages deployment workflow.

## Local verification

Run the repository check from the root:

```powershell
node scripts/verify-repository.mjs
```

To preview the website:

```powershell
python -m http.server 4173 --directory website
```

The iOS project cannot be built on Windows. On macOS, open `ios/EyeRest.xcodeproj` in Xcode and follow [`ios/README.md`](ios/README.md). An unsigned archive is not installable on a normal iPhone; valid developer signing is required.
