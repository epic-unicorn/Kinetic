# Kinetic Link — Kids App

Child-facing Flutter app. Children see tasks assigned by a parent, mark them done, and earn XP.

## Screens

| Screen | Description |
|---|---|
| **Home** | Pending and completed task lists. Tap to open detail. Sync button in the app bar triggers a manual WebDAV pull/push. |
| **Task detail** | Category, priority, due date, XP reward, notes. "Klaar!" button completes the task and queues a sync push. |

## How sync works

On startup and every app resume:
1. WebDAV credentials are read from secure storage (set up once by copying from the parent app)
2. `KidsSyncOrchestrator` pulls all files from `/kinetic/shared/tasks/` (family-key encrypted)
3. Tasks are merged into local SQLite (Last-Write-Wins on `updatedAt`)
4. Locally-completed tasks are pushed back to WebDAV

## Development

```bash
cd apps/kids
flutter run        # run on device/emulator
flutter test       # run all tests
flutter build apk --release
```

## Backlog

- XP total display in the UI header
- Parent approval workflow
- Activity badges and family leaderboard
