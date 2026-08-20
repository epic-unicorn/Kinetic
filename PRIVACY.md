# Privacy Policy — Kinetic Link

**Last updated:** 2026-08-20

Kinetic Link (parent app `net.moonbaseone.kinetic.parent` and kids app `net.moonbaseone.kinetic.kids`) is local-first software. There is no Kinetic cloud account and no telemetry.

## Data we collect

**None.** The apps do not send analytics, crash reports, advertising identifiers, or usage metrics to us or to third-party trackers.

## Data stored on your device

- Tasks, notes, proposals, and settings in a local SQLite database
- Encryption keys and WebDAV credentials in platform secure storage (Android Keystore / iOS Keychain)
- Optional encrypted `.kvault` backup files you export yourself

Android auto-backup is disabled (`allowBackup=false`).

## Optional WebDAV sync

If you configure a WebDAV server (for example Nextcloud), encrypted blobs are stored **on that server under your control**. Kinetic does not operate the server.

- Sync uses HTTP Basic authentication to your server
- Personal data is encrypted with AES-256-GCM using a key derived from your 12-word recovery phrase
- Shared family data is encrypted with the family key

We never receive your WebDAV password, recovery phrase, or decrypted content.

## Camera

Camera access is used only to scan QR codes for partner pairing or kids enrollment. Images are not uploaded or stored by Kinetic.

## Notifications

Local notifications remind you about tasks you schedule. They are generated on-device and are not sent through a push vendor.

## Children

The kids app stores the same kinds of local and optional WebDAV data for assigned chores. Parents control enrollment via QR. No child accounts are created with Kinetic.

## Contact

For privacy questions, open an issue on the project repository: https://github.com/ingmarstruijs/Kinetic
