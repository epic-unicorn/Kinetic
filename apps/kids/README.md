# Kinetic Link — Kids App

Child-facing Flutter app. Children see tasks assigned by a parent via the parent's unique QR enrollment code, mark them done, and earn XP.

Parent-app themes, reminder picker, notes list, and the suggestion engine do **not** apply here. Enrollment uses a family-key QR **without** the WebDAV password; the parent types that password once on the kids device.

## Setup

1. Parent generates enrollment QR in Settings → Family → Kids → "Link kids app"
2. Parent shows QR to child
3. Child opens Kinetic Kids app → scans QR → types the WebDAV password
4. Kid device is enrolled with:
   - WebDAV credentials (server, username, password typed on device)
   - Family key (for decryption)
   - Kid UUID (stored in secure storage as `kinetic_kid_id`)
5. Tasks are synced from `/kinetic/shared/tasks/` and filtered by this UUID

## Screens

| Screen | Description |
|---|---|
| **Home** | Pending and completed task lists. Tap to open detail. Sync button in the app bar triggers a manual WebDAV pull/push. |
| **Task detail** | Category, priority, due date, XP reward, notes. **Done!** button completes the task (sets `status: completed`) and queues a sync push. |

## How sync works

On startup and every app resume:
1. WebDAV credentials + kid UUID read from secure storage (set during enrollment)
2. `KidsSyncOrchestrator` pulls all files from `/kinetic/shared/tasks/` (family-key encrypted)
3. Each task's `xKineticTargetKidId` iCal property is checked; only tasks matching this kid's UUID are imported
4. Tasks are merged into local SQLite (Last-Write-Wins on `updatedAt`)
5. Locally-completed tasks are pushed back to WebDAV

**First-time sync**: If the local database is empty and remote files exist, matching tasks are imported. Any subsequent local/remote changes use Last-Write-Wins merge.

## Development

```bash
cd apps/kids
flutter run        # run on device/emulator
flutter test       # run all tests
flutter build apk --release
```

## Architecture

```
lib/
├── db/            — Drift schema (KidsTask model)
├── enrollment/    — QR scan screen, confirmation dialog
├── sync/          — KidsSyncOrchestrator (pulls from /kinetic/shared/), WebDavConfigRepository
├── task/          — task screens, local repository
├── theme/         — Material 3 color schemes
└── main.dart      — root shell with enrollment flow
```

## Secure Storage Keys
- `kinetic_webdav_server_url` — WebDAV server URL
- `kinetic_webdav_username` — WebDAV username
- `kinetic_webdav_password` — WebDAV password
- `kinetic_webdav_personal_key` — Personal key (unused on kids device; set to dummy)
- `kinetic_webdav_family_key` — Family key (decrypts assigned tasks)
- `kinetic_kid_id` — This device's child UUID (for filtering xKineticTargetKidId)
