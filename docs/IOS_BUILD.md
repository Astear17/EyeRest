# EyeRest

EyeRest is an offline SwiftUI iPhone app for eye relaxation, hydration, blinking, posture, and movement reminders. It targets iOS 17+ and is laid out for an iPhone XS (375 × 812 points) while supporting Dynamic Type and VoiceOver.

## Architecture

`Models` contains Codable reminder and preference models. `Services` owns local persistence and the notification queue. `ViewModels` reconciles schedules, state and completion history. `Views` is the SwiftUI interface. There are no packages, network clients, analytics SDKs, or backend dependencies.

Notification schedules use absolute calendar dates, not a repeating background timer. At most eight future occurrences per enabled kind are queued (40 total at the standard five kinds), leaving room below iOS’s 64-pending-notification limit. The app removes and regenerates its own pending requests after a configuration change and whenever it becomes active. iOS cannot guarantee notifications indefinitely if the app is never opened again: open EyeRest periodically so it can replenish the batch.

## macOS/Xcode build

1. Clone this repository to your macOS working folder.
2. Open `EyeRest.xcodeproj` in Xcode 15 or later on macOS.
3. In **Signing & Capabilities**, select your development team for device testing. The bundle identifier is `com.astear17.eyerest`.
4. Verify the deployment target is iOS 17.0. Run on an iPhone XS using iOS 17 or iOS 18.
5. For the Time Sensitive mode, enable **Time Sensitive Notifications** under the app’s iPhone notification settings. This app never requests Critical Alerts.

### Command-line validation on macOS

```bash
xcodebuild -project EyeRest.xcodeproj -scheme EyeRest -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15' clean build | tee BuildLogs/simulator-build.log
xcodebuild -project EyeRest.xcodeproj -scheme EyeRest -configuration Release \
  -archivePath Build/EyeRest.xcarchive archive
```

An unsigned archive is useful for inspection but it is **not automatically an installable IPA**. iOS devices require the executable to be code signed. Apple does not permit a genuinely unsigned app to be installed on a normal iPhone.

## GitHub Actions builds

The repository’s **EyeRest iOS Build** workflow makes an Xcode installation unnecessary for automated compilation. It runs for pushes to `main`, pull requests that target `main`, and manual dispatches. To start it manually, open the repository’s **Actions** tab, choose **EyeRest iOS Build**, then select **Run workflow**.

The workflow uses GitHub-hosted `macos-15`, explicitly switches to `/Applications/Xcode_16.4.app`, discovers the one tracked shared scheme, and invokes `xcodebuild` with these important settings:

```bash
-configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=''
```

No developer certificate, provisioning profile, signing secret, third-party build action, or account credential is used. Each completed run retains its `eyerest-ios-unsigned-<commit>` artifact for 14 days. Download it from the run’s **Artifacts** section. It contains a zipped `.app`, `EyeRest-unsigned.ipa`, `xcodebuild.log`, and `build-metadata.json` (commit SHA, version, build number, Release configuration, SDK, and signing state).

`EyeRest-unsigned.ipa` is deliberately labelled as **unsigned** and is for inspection only. It has the expected `Payload/EyeRest.app` structure but cannot be installed on a normal iPhone. A development-signed archive and export, or an authorized re-signing process, is still required for a device-installable IPA.

### CI troubleshooting

- **Xcode selection failed:** the runner image may have changed. The workflow prints the Xcode applications it found; update the explicitly selected version and path together after checking GitHub’s macOS runner-image notes.
- **Project or scheme discovery failed:** confirm `EyeRest.xcodeproj` and `EyeRest.xcodeproj/xcshareddata/xcschemes/EyeRest.xcscheme` are tracked, and that there is only one shared scheme.
- **`xcodebuild` failed:** download the workflow’s `xcodebuild.log`; it is uploaded even when the build step fails. Fix the reported project, SDK, or Swift compiler issue and rerun the workflow.
- **IPA will not install:** this is expected for an unsigned IPA. Use valid Apple signing for an installable build; do not add credentials to this unsigned CI workflow.

## IPA packaging and sideloading

For a sideloadable IPA, archive with a valid Apple Development signing identity and export with an `ExportOptions.plist` suitable for `development` (or use AltStore/Sideloadly with the Xcode-produced archive). Re-signing tools require an Apple ID/development certificate; follow their current instructions. An unsigned `.ipa` can be constructed for static inspection only and cannot be installed on an iPhone.

Run `scripts/package-unsigned-ipa.sh` on macOS after the unsigned archive succeeds. It validates the `Payload/EyeRest.app` layout and writes `Build/EyeRest-unsigned.ipa`. It intentionally warns that the result is not installable.

## iOS limitations

- Local notification delivery is controlled by iOS; Focus, notification summaries, disabled permissions, battery state, and system policies may defer or suppress delivery.
- Time Sensitive delivery requires both authorization and the per-app iOS setting. It is not Critical Alerts and does not bypass all system controls.
- There is no continuous background process. Countdown display updates only while the app is foregrounded; its value is always computed from absolute dates.
- Snooze is a single 10-minute local notification; quiet-hours behavior applies to the normal recurring batch.
