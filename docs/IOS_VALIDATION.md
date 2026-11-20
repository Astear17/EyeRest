# Validation status — 20 November 2026

## Automated validation

`node scripts/verify-repository.mjs` checks project membership, required build settings, Info.plist metadata, localization catalog structure, workflow safeguards, signing-file exclusions, and basic Swift delimiter balance. It is a static check, not a Swift compiler.

The **EyeRest iOS Build** workflow performs the authoritative Release build on `macos-15` with Xcode 16.4 and signing disabled. A successful build job verifies:

- the shared `EyeRest` scheme compiles for generic iOS devices in Release;
- the processed app plist resolves the expected executable, `APPL` package type, bundle identifier, version, build number, bundle name, and Info.plist format version;
- the app contains its executable plus English and Vietnamese localization output;
- the IPA has `Payload/EyeRest.app` and passes `unzip -t`;
- the artifact contains `EyeRest-unsigned.ipa`, `EyeRest-unsigned.app.zip`, `EyeRest-Info.plist`, `build-metadata.json`, and `xcodebuild.log`.

The separate `logic-tests` job runs deterministic Foundation-only planner, quiet-hours, and persistence tests with `swift test`.

## Device validation still required

CI cannot prove notification delivery, permission UI, Time Sensitive capability after Feather/KSign re-signing, cold-launch actions, Dynamic Type layout, VoiceOver announcements, locale changes, background cancellation of the eye-rest session, or preservation of data across an installed upgrade. Validate those behaviours on a physical iPhone after re-signing with a valid certificate and provisioning profile.

The CI IPA is intentionally unsigned. A successful archive and integrity check does not make it directly installable.
