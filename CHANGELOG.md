# Changelog

All notable EyeRest changes are recorded here. The project has not yet published its first tagged release.

## Unreleased

### Added

- Versioned offline settings and activity persistence with migration coverage.
- Validated JSON backup export/import, checksum verification, preview, and one-use undo.
- Active-day, quiet-hour, pause, and optional snooze scheduling rules.
- Four guided break activities with pause/resume, background auto-pause, haptics, and Reduce Motion support.
- Activity streaks, weekly totals, accessible chart, and 30-day history.
- Localized welcome flow, English and Vietnamese strings, and the eye-clock app icon with light, dark, and tinted variants.
- Unsigned CI IPA packaging, checksum output, and tag-gated release automation.
- Offline medicine reminders with local Taken, Skipped, and Snoozed history, notification actions, privacy controls, and version 2 backups.

### Changed

- Documentation now describes unsigned distribution, user-provided signing, capability limits, and physical-device validation accurately.

### Known limitations

- Physical-device installation, upgrade behavior, signing-tool compatibility, and notification delivery still require the owner checklist.
- Free Apple ID signing commonly expires after about seven days.
- Time Sensitive notifications depend on the final signing profile and the user's iOS settings; normal delivery is the fallback.
