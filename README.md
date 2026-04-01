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

## Building a release APK

```bash
cd apps/parent   # or apps/kids
flutter build apk --release
```