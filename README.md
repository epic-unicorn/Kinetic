# Kinetic Link

Local-first family task management. Parents manage encrypted tasks and notes locally, with optional WebDAV sync for shared family data. No accounts, no telemetry, no cloud lock-in.

## Apps

| App | Platforms | Description |
|---|---|---|
| `apps/parent` | Android, iOS | Task manager, partner proposals, notes, WebDAV config |
| `apps/kids` | Android | Assigned tasks synced from parent via WebDAV |

Shared crypto/sync logic lives in `packages/webdav` (AES-256-GCM, iCal, WebDAV client).

## Quick start

```bash
dart pub global activate melos
melos bootstrap
melos run test        # run all tests
cd apps/parent && flutter run
```

No server required — the app works fully offline. Configure WebDAV in Settings to enable sync.

## Data Migration & Recovery

When upgrading to a new version with existing WebDAV data, the parent app automatically detects remote tasks and notes and offers to import them or clean them up. This handles the case where a fresh install generates a new personal encryption key that can't decrypt old data.

**Backup & Restore features** (Settings > Back-up & Herstel):

- **Export recovery key**: Save your personal key as JSON for multi-device sync or disaster recovery
- **Import recovery key**: Restore a previously exported key to decrypt old tasks/notes with the original encryption

This enables seamless multi-device setup — export your key on your primary device and import it on any new device to access your existing encrypted data.

## Building a release APK

```bash
cd apps/parent   # or apps/kids
flutter build apk --release
```