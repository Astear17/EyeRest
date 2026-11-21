# Sideloading EyeRest

EyeRest is not distributed through the App Store. GitHub Releases contain an **unsigned IPA**: a packaged iOS app without a device-trusted signature. It cannot run on a normal iPhone until a signing tool signs it with a certificate and provisioning profile.

## Before changing an installed copy

Export an EyeRest backup before reinstalling, changing signing tools, or changing Apple accounts. A tool may assign a different bundle identifier; iOS then creates a separate app whose local data does not include the old app's settings or history.

## Download and verify

Download `EyeRest-unsigned.ipa` and `EyeRest-unsigned.ipa.sha256` from the same [GitHub Release](https://github.com/Astear17/EyeRest/releases/latest). If the Releases page is empty, the first release has not been published yet.

In PowerShell, from the download directory:

```powershell
Get-FileHash .\EyeRest-unsigned.ipa -Algorithm SHA256
Get-Content .\EyeRest-unsigned.ipa.sha256
```

On macOS or Linux:

```bash
shasum -a 256 EyeRest-unsigned.ipa
cat EyeRest-unsigned.ipa.sha256
```

The 64-character hexadecimal values must match exactly. Delete the download and try again if they do not.

## Sign and install

1. Choose a signing tool you trust and follow its own documentation.
2. Sign `EyeRest-unsigned.ipa` with your certificate and provisioning profile.
3. Install the signed result on an iPhone running iOS 17 or later.
4. If iOS requests it, enable **Settings > Privacy & Security > Developer Mode**, restart, and confirm the prompt.
5. Open EyeRest and choose whether to allow notifications.

EyeRest does not require Xcode to use an IPA that another tool can sign and install. Each tool has different platform, account, certificate, and extension-handling requirements.

## Compatibility classes

| Class | Meaning |
| --- | --- |
| Works with ordinary signing | Core UI, local storage, guided breaks, activity history, and normal local notifications use standard app capabilities. |
| Needs a profile capability | Time Sensitive notification delivery depends on the final provisioning profile and the user's iOS setting; EyeRest falls back to normal notifications. |
| Depends on tool handling | A signing tool may rewrite the bundle identifier or handle entitlements differently, which can create a separate install or remove optional behavior. |
| Not reliably supportable | A revoked or expired certificate, invalid P12/password, or incompatible provisioning profile cannot be repaired by EyeRest. |

## Tested-with record

Do not interpret this list as an endorsement. Physical-device compatibility has not yet been validated.

| Tool | Status | Notes |
| --- | --- | --- |
| Feather | Not yet tested | Record version, platform, certificate type, bundle identifier, and result after testing. |
| KSign | Not yet tested | Record version, platform, certificate type, bundle identifier, and result after testing. |
| Sideloadly | Not yet tested | Record version, platform, Apple account type, bundle identifier, and result after testing. |
| AltStore | Not yet tested | Record version, platform, Apple account type, bundle identifier, and result after testing. |

## What to expect

- Free Apple ID signing commonly expires after about seven days. The app then stops opening until it is signed and installed again.
- Re-signing with the same bundle identifier may preserve data, but always export a backup first.
- iOS limits pending local notifications, so open EyeRest periodically to replenish its queue.
- Focus, notification summaries, permissions, battery state, and iOS policy can delay or suppress delivery.
- An unsigned CI build proves compilation and packaging, not installation or notification delivery on an iPhone.

## Troubleshooting

- **The app will not install:** check that the IPA was signed, the device is included when required, the profile is current, and Developer Mode is enabled if requested.
- **The app opens and immediately stops later:** check whether a free-signing profile or certificate expired, then re-sign and reinstall.
- **A second EyeRest icon appears:** the signing tool changed the bundle identifier. Export from the old copy before removing it, then import into the new copy.
- **Time Sensitive is unavailable:** confirm both the profile capability and **Settings > Notifications > EyeRest > Time Sensitive Notifications**. Normal notifications remain available.
- **No reminder arrives:** check notification permission, Focus, the app's pause/active-day/quiet-hour settings, and reopen EyeRest to replenish the queue.
