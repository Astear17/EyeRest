# EyeRest

EyeRest is an offline SwiftUI iPhone app for eye relaxation, hydration, blinking, posture, and movement reminders. It targets iOS 17+ and is laid out for an iPhone XS (375 × 812 points) while supporting Dynamic Type and VoiceOver.

## Architecture

`Models` contains Codable reminder and preference models. `Services` owns local persistence and the notification queue. `ViewModels` reconciles schedules, state and completion history. `Views` is the SwiftUI interface. There are no packages, network clients, analytics SDKs, or backend dependencies.

Notification schedules use absolute calendar dates, not a repeating background timer. At most eight future occurrences per enabled kind are queued (40 total at the standard five kinds), leaving room below iOS’s 64-pending-notification limit. The app removes and regenerates its own pending requests after a configuration change and whenever it becomes active. iOS cannot guarantee notifications indefinitely if the app is never opened again: open EyeRest periodically so it can replenish the batch.

## macOS/Xcode build

1. Copy this folder to `D:\GitHub\EyeRest` (or your macOS working folder).
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

## IPA packaging and sideloading

For a sideloadable IPA, archive with a valid Apple Development signing identity and export with an `ExportOptions.plist` suitable for `development` (or use AltStore/Sideloadly with the Xcode-produced archive). Re-signing tools require an Apple ID/development certificate; follow their current instructions. An unsigned `.ipa` can be constructed for static inspection only and cannot be installed on an iPhone.

Run `Scripts/package-unsigned-ipa.sh` on macOS after the unsigned archive succeeds. It validates the `Payload/EyeRest.app` layout and writes `Build/EyeRest-unsigned.ipa`. It intentionally warns that the result is not installable.

## iOS limitations

- Local notification delivery is controlled by iOS; Focus, notification summaries, disabled permissions, battery state, and system policies may defer or suppress delivery.
- Time Sensitive delivery requires both authorization and the per-app iOS setting. It is not Critical Alerts and does not bypass all system controls.
- There is no continuous background process. Countdown display updates only while the app is foregrounded; its value is always computed from absolute dates.
- Snooze is a single 10-minute local notification; quiet-hours behavior applies to the normal recurring batch.
