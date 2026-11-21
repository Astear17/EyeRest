# EyeRest release checklist

Complete this checklist on a physical iPhone running iOS 17 or later. Record the device, iOS version, signing tool and signing profile used. A green unsigned CI build does not replace these checks.

## Install and upgrade

- [ ] Install the newly signed IPA as a fresh install and confirm the welcome screen appears before any notification prompt.
- [ ] Tap **Get started**, deny notification permission, and confirm Home shows the disabled-notifications banner without a second alert.
- [ ] Repeat on a fresh install, allow notification permission, and confirm reminders can be scheduled.
- [ ] Install over the previous EyeRest build and confirm reminder settings, quiet hours, appearance, active days and activity history remain intact; existing users must not see welcome automatically.
- [ ] In Settings > About, open **Show welcome**, confirm **Done** dismisses it, and confirm replay does not request permission.
- [ ] If the signing tool changes the bundle identifier, export a backup before reinstalling; verify the old and new identifiers behave as separate installs.
- [ ] With free Apple ID signing, confirm and document the expected approximately seven-day expiry and re-signing flow.

## Notifications and schedules

- [ ] Exercise permission denied, allowed and later-disabled states.
- [ ] Enable each of the five reminder kinds and confirm its localized title and message.
- [ ] With Snooze off, confirm no Snooze action appears. Repeat with 5, 10 and 15 minutes.
- [ ] Confirm hydration and blinking use **Done** plus optional **Snooze**; guided eye-rest, posture and movement notifications use optional **Snooze** only.
- [ ] Tap each guided notification and confirm it opens the matching activity.
- [ ] Confirm Snooze respects pause, active days and quiet hours and is ignored while reminders are paused.
- [ ] Make rapid interval, enable/disable, active-day and quiet-hour edits; confirm no duplicate or stale pending alerts.
- [ ] Pause for one hour, for the rest of today, and indefinitely. Confirm **Resume reminders** works.
- [ ] For **Pause for rest of today**, leave the app closed across midnight and confirm queued reminders resume automatically.
- [ ] Change time zone, locale and device time significantly; reopen EyeRest and confirm pending notifications reconcile without duplicates.
- [ ] Confirm Time Sensitive falls back to normal delivery when the re-signed profile does not carry that capability.

## Guided breaks and activity

- [ ] Complete Eye rest, Eye relaxation, Posture check, and Stand up and move; verify every step, duration and safety note.
- [ ] Pause and resume each activity and confirm the ring and remaining time stay consistent.
- [ ] Background a running activity, return, and confirm it is paused with remaining time preserved.
- [ ] End early and confirm no activity event is recorded.
- [ ] Complete a session and confirm exactly one guided event is recorded with the correct duration.
- [ ] Confirm step-change and completion haptics with Haptics on, and no haptics with it off.
- [ ] Confirm current streak, best streak, weekly break time, seven-day chart and 30-day history agree with completed sessions.
- [ ] Confirm a fresh install has clear chart and history empty states.

## Accessibility and localization

- [ ] Set Dynamic Type to the largest accessibility size and inspect every tab, reminder detail, Settings section, welcome screen, backup dialog and guided activity for clipping or unreachable controls.
- [ ] With VoiceOver, confirm logical reading order, meaningful control labels, selected active-day state, chart summary, history details and guided-step announcements.
- [ ] Turn on Reduce Motion and confirm the break ring updates once per second with no step or completion transitions.
- [ ] Confirm every interactive target is at least 44 points and no state is communicated by color alone.
- [ ] Switch the app language to Vietnamese and inspect every screen, notification action, activity, dialog, empty state and accessibility label for missing or clipped translations.
- [ ] Check the app icon on the Home Screen and in Settings at small sizes in light, dark and tinted appearances where supported.

## Backup and recovery

- [ ] Export a backup containing changed settings and completed activity history.
- [ ] Inspect the preview, import it, and confirm settings/history are restored without importing notification permission or pending alerts.
- [ ] Use **Undo last import** once and confirm the pre-import data returns; confirm the undo is not reusable.
- [ ] Try a damaged or modified backup and confirm no existing data changes.

## Distribution record

- [ ] Record the exact commit and successful GitHub Actions run used for the IPA.
- [ ] Verify the published IPA SHA-256 against its `.sha256` file.
- [ ] Confirm the IPA is described as unsigned and requires user signing; do not imply App Store availability.
- [ ] Record signing-tool compatibility as tested only after completing the full install and upgrade flow with that tool.
