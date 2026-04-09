# Kinetic Link

Local-first family task management. Parents manage encrypted tasks and notes locally, coordinate with co-parents via proposals, and manage children's assigned tasks — all with optional WebDAV sync. No accounts, no telemetry, no cloud lock-in.

## Apps

| App | Platforms | Description |
|---|---|---|
| `apps/parent` | Android, iOS | Task manager, partner coordination (proposals), notes, child task overview, WebDAV config |
| `apps/kids` | Android | Assigned tasks synced from parent via WebDAV; children mark tasks complete and earn XP |

Shared crypto/sync logic lives in `packages/webdav` (AES-256-GCM, iCal, WebDAV client).

## Architecture Overview

### Encryption
- **Personal Key**: Unique per parent device; encrypts personal tasks & notes
- **Family Key**: Shared across family devices via QR pairing; encrypts proposals, shared notes, assigned tasks
- **Kid UUID**: Each enrolled child device receives unique ID for task targeting

### Family Connections
- **Partner pairing**: Share QR code with partner to sync proposals; marked via `kinetic_partner_paired` flag
- **Kids enrollment**: Parent generates QR with family key + kid UUID; kid device scans to enroll
- **Familie screen**: Conditionally shows "Voorstellen" (proposals) and "Kinderen" (kids tasks) tabs based on what's connected

## Quick start

```bash
dart pub global activate melos
melos bootstrap
melos run test        # run all tests
cd apps/parent && flutter run
```
No server required — the app works fully offline. Configure WebDAV in Settings to enable sync and pairing.

## Building a release APK

```bash
cd apps/parent   # or apps/kids
flutter build apk --release
```