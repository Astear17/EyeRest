# EyeRest backup format

EyeRest exports a UTF-8 JSON document named `EyeRest-Backup-YYYY-MM-DD.json`. The file is portable between EyeRest installations and contains only local settings and activity history. The current backup schema is version 1.

```json
{
  "format": "com.astear17.eyerest.backup",
  "schemaVersion": 1,
  "appVersion": "1.0",
  "exportedAt": 817747200000,
  "settings": {},
  "activity": {
    "events": [],
    "dailyTotals": []
  },
  "payloadSHA256": "lowercase hexadecimal SHA-256"
}
```

Dates use milliseconds since the Unix epoch, the representation produced by `JSONEncoder.DateEncodingStrategy.millisecondsSince1970` in this format. Object keys are sorted before hashing. `payloadSHA256` is the SHA-256 digest of the same canonical, pretty-printed JSON document with the checksum field omitted.

The settings payload includes the persisted reminder configurations and user preferences defined by `AppPreferences`, including pause, active-day, quiet-hour, appearance, snooze, haptics, and welcome state. It deliberately excludes each reminder's derived next fire date, notification authorization, pending notification requests, and all other operating-system notification state. EyeRest rebuilds that state after import. The activity payload contains retained raw completion events and permanent daily totals.

Import validates the complete document, schema, checksum, and value ranges before changing anything. A schema version newer than the app supports is rejected. Events merge by UUID, settings are replaced, and a one-use in-memory snapshot allows the most recent import to be undone while the app remains running. A failed validation or failed atomic activity-file write leaves current app data unchanged.

The checksum protects against accidental damage; it is not a digital signature and does not prove who created a backup. Backups can contain private routine and activity information, so the user chooses where to store or share an exported file.
