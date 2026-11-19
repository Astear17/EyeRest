# EyeRest

EyeRest is an in-development, offline-first iPhone wellness reminder. Its native SwiftUI app is designed to encourage eye breaks, hydration, natural blinking, posture checks, and movement—without accounts, advertising, tracking, or a cloud dependency.

## Development requirements

- **iOS app:** macOS with Xcode 15 or newer; iOS 17.0 deployment target.
- **Website:** any modern browser and a static HTTP server.
- **Node.js:** only required for the repository verification script.

## Repository structure

```text
EyeRest/                 # Native SwiftUI source
EyeRest.xcodeproj/       # Xcode project
website/                 # Consumer product website deployed by GitHub Pages
docs/                    # iOS development, build, and validation notes
scripts/                 # Repository verification and IPA packaging scripts
.github/workflows/       # GitHub Pages workflow (publishes website/ only)
```

## Open the iOS project

On macOS, open `EyeRest.xcodeproj` in Xcode. Select an Apple development team before installing on a physical device. The app has not been compiled or device-validated in this Windows environment; see [docs/IOS_BUILD.md](docs/IOS_BUILD.md) and [docs/IOS_VALIDATION.md](docs/IOS_VALIDATION.md) for the required macOS checks.

## Preview the website

```powershell
python -m http.server 4173 --directory website
```

Open `http://127.0.0.1:4173` in a browser. The Pages workflow publishes `website/` directly, so there is no build step or framework-specific base-path configuration.

## Verify the repository

```powershell
node scripts/verify-repository.mjs
```

This checks required files, website asset paths, Pages deployment configuration, key iOS project settings, and accidentally committed signing or environment files. It does not replace `xcodebuild` or device validation on macOS.
