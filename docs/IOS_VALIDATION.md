# Validation status — 19 November 2026

## Completed in this environment

- Project-file structural inspection: passed (all Swift file references and required source files exist).
- Offline dependency inspection: passed (no third-party package manifests, URLs, API clients, or external frameworks).
- Configuration inspection: passed (`com.astear17.eyerest`, iOS 17.0, iPhone-only target, notification Time Sensitive entitlement).
- IPA validation: not run. No macOS/Xcode toolchain or `.xcarchive` exists in this Windows environment.

## Required macOS validation commands

Run the two `xcodebuild` commands in `README.md`, then run:

```bash
./scripts/package-unsigned-ipa.sh Build/EyeRest.xcarchive | tee BuildLogs/package.log
unzip -t Build/EyeRest-unsigned.ipa | tee BuildLogs/ipa-integrity.log
unzip -l Build/EyeRest-unsigned.ipa | grep 'Payload/EyeRest.app/Info.plist'
```

Only report a successful iOS compilation or IPA generation after those commands exit successfully on macOS.
