# EyeRest

EyeRest is a privacy-first, offline wellness reminder project for iPhone. The native SwiftUI project lives at the repository root; the website remains independently deployable from `website/`.

## Repository map

- [`EyeRest.xcodeproj`](EyeRest.xcodeproj) and [`EyeRest/`](EyeRest/) — native iOS 17+ SwiftUI project and source.
- [`website/`](website/) — dependency-free static landing site deployed with GitHub Pages.
- [`docs/`](docs/) — iOS development, build, and validation notes.
- [`scripts/`](scripts/) — repository validation and unsigned IPA packaging scripts.
- [`.github/workflows/pages.yml`](.github/workflows/pages.yml) — Pages deployment workflow, publishing only `website/`.

## Local verification

Run the repository check from the root:

```powershell
node scripts/verify-repository.mjs
```

To preview the website:

```powershell
python -m http.server 4173 --directory website
```

The iOS project cannot be built on Windows. On macOS, open `EyeRest.xcodeproj` in Xcode and follow [`docs/IOS_BUILD.md`](docs/IOS_BUILD.md). An unsigned archive is not installable on a normal iPhone; valid developer signing is required.
