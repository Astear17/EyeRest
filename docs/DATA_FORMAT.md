# EyeRest backup format

EyeRest exports a UTF-8 JSON document named `EyeRest-Backup-YYYY-MM-DD.json`. It contains local settings, activity history, medicine reminders, and medicine history. The current backup schema is version 2; version 1 backups still import and leave existing medicine data unchanged.

```json
{
  "format": "com.astear17.eyerest.backup",
  "schemaVersion": 2,
  "appVersion": "1.0",
  "exportedAt": 817747200000,
  "settings": {},
  "activity": {
    "events": [],
    "dailyTotals": []
  },
  "medicine": {
    "reminders": [],
    "log": [],
    "hideNamesInNotifications": false,
    "hasAcknowledgedNotice": false
  },
  "payloadSHA256": "lowercase hexadecimal SHA-256"
}
```

Dates use milliseconds since the Unix epoch, the representation produced by `JSONEncoder.DateEncodingStrategy.millisecondsSince1970` in this format. Object keys are sorted before hashing. `payloadSHA256` is the SHA-256 digest of the same canonical, pretty-printed JSON document with the checksum field omitted.

The settings payload includes the persisted reminder configurations and user preferences defined by `AppPreferences`, including pause, active-day, quiet-hour, appearance, snooze, haptics, and welcome state. It deliberately excludes each reminder's derived next fire date, notification authorization, pending notification requests, and all other operating-system notification state. EyeRest rebuilds that state after import. The activity payload contains retained raw completion events and permanent daily totals.

Import validates the complete document, schema, checksum, and value ranges before changing anything. A schema version newer than the app supports is rejected. Activity and medicine log events merge by UUID. Settings are replaced; medicine reminders are replaced only when the optional medicine section exists. A one-use in-memory snapshot allows the most recent import to be undone while the app remains running.

The checksum protects against accidental damage; it is not a digital signature. Backups can contain private routine, activity, medicine-name, schedule, and medicine-history information, so the user chooses where to store or share an exported file.
