# EyeRest iOS build and distribution

EyeRest is an offline SwiftUI iPhone app targeting iOS 17.0 with Swift 5.9. The Xcode project has one shared `EyeRest` scheme and no external dependencies.

## Local macOS validation

Create the log directory before piping output to `tee`:

```bash
mkdir -p BuildLogs
node scripts/verify-repository.mjs | tee BuildLogs/repository-verification.log
swift test 2>&1 | tee BuildLogs/swift-test.log
xcodebuild -project EyeRest.xcodeproj -scheme EyeRest -configuration Release \
  -sdk iphoneos -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY='' \
  clean build 2>&1 | tee BuildLogs/release-build.log
```

For normal device development, select a valid Apple development team and build the same scheme onto an iOS 17+ iPhone. Do not add signing material to the repository.

## GitHub Actions

The **EyeRest iOS Build** workflow runs for relevant pushes to `main`, pull requests targeting `main`, manual dispatch, and tags matching `v*`. It pins GitHub `macos-15` to `/Applications/Xcode_16.4.app`, runs the repository verifier, builds Release for generic iOS with code signing disabled, validates the processed app metadata, localization resources, compiled `Assets.car`, and processed AppIcon metadata, packages the unsigned app and IPA, and integrity-checks the IPA. The workflow log also reports whether Xcode emitted a standalone `AppIcon60x60@2x.png`; the asset catalog remains authoritative either way. A separate job runs the Foundation-only Swift package tests.

The 14-day artifact remains named `eyerest-ios-unsigned-<sha>` and contains:

- `EyeRest-unsigned.ipa`
- `EyeRest-unsigned.ipa.sha256`
- `EyeRest-unsigned.app.zip`
- `EyeRest-Info.plist`
- `build-metadata.json`
- `xcodebuild.log`

The IPA must contain `Payload/EyeRest.app/EyeRest`, the processed Info.plist, and compiled `en.lproj` and `vi.lproj` localization resources.

Manual dispatch is a dry run: it uploads the same 14-day artifact but never publishes a release. After the repository owner completes physical-device testing and pushes a `v*` tag, the tag run waits for both the logic-tests and build jobs, verifies the checksum, then publishes a GitHub Release containing only `EyeRest-unsigned.ipa`, `EyeRest-unsigned.ipa.sha256`, and `build-metadata.json`. Write permission is scoped to that tag-only release job. The workflow never signs the app and contains no signing secret.

## Time Sensitive and sideloading

The unsigned CI artifact embeds no usable device signature or provisioning profile. A compatible signing tool must re-sign it with valid credentials before installation. Time Sensitive delivery works only when the re-signing certificate and provisioning profile carry the capability and the user enables it in iPhone notification settings. Otherwise EyeRest deliberately schedules normal `.active` notifications. Never add a certificate, P12 password, provisioning profile, or signing secret to this workflow. See [SIDELOADING.md](SIDELOADING.md) for the owner-maintained compatibility record.

A P12 MAC verification failure is a credential or password problem, not an IPA source-code problem. The app cannot work around an invalid P12.

## iOS scheduling limitations

- iOS controls final delivery; Focus, summaries, permissions, battery state, and system policy can delay or suppress notifications.
- EyeRest uses absolute, non-repeating requests so quiet hours and time-zone changes can be handled explicitly.
- At most 58 normal requests are queued, reserving six of the system's 64 slots for snoozes. Open EyeRest periodically to replenish the finite queue.
- Snooze is one absolute request per reminder kind and is adjusted through the same active-day and quiet-hours rules as regular reminders.
- English and Vietnamese follow the system or per-app language; changing locale causes pending notification text to be rebuilt.
- There is no continuous background process. Countdown rendering occurs only while the app is visible.

## Troubleshooting

- If Xcode selection fails, inspect the runner's installed applications and update the pinned Xcode version deliberately.
- If compilation fails, download `xcodebuild.log` from the artifact uploaded by the failed job.
- If the IPA fails metadata checks, inspect `EyeRest-Info.plist` and `build-metadata.json` from the same run.
- If installation or Time Sensitive delivery fails after a green build, validate the re-signing certificate, P12 password, private key, provisioning profile, and on-device notification settings.
