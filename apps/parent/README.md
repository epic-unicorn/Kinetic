# Kinetic Link — Parent App

Parent-facing Flutter app. Manage personal tasks and notes locally, coordinate with your co-parent via task proposals, and optionally sync to a WebDAV server.

## Screens

| Screen | Description |
|---|---|
| **Taken** | Personal task manager — quick-add, swipe-to-complete, priorities, categories, due dates, recurrence. |
| **Partner** | Incoming task proposals (accept/snooze/dismiss) + family workload metrics. |
| **Notities** | Markdown notes, personal or shared, synced to WebDAV when configured. |
| **Instellingen** | WebDAV config, connection test, theme selector. **Back-up & Herstel** section for recovery key export/import. |

## Development

```bash
cd apps/parent
flutter run        # run on device/emulator
flutter test       # run all tests
flutter build apk --release
```

All secrets are stored at runtime via secure storage — no `--dart-define` flags needed.

## Architecture

```
lib/
├── db/        — Drift schema (PersonalTasks + PersonalNotes)
├── todo/      — task & note models, repositories, screens
├── partner/   — proposals, load metrics
├── settings/  — WebDAV config, theme preference
├── sync/      — SyncOrchestrator (WebDAV pull/push, LWW merge)
├── theme/     — Material 3 color schemes
└── main.dart
```

### WebDAV layout

```
/kinetic/{username}/
├── tasks/personal.ics   — personal tasks (personal key)
├── tasks/shared.ics     — tasks for kids (family key)
├── notes/personal.ics   — personal notes (personal key)
├── notes/shared.ics     — shared notes (family key)
└── shared/
    ├── load/{username}.json   — workload metrics (family key)
    ├── proposals/{id}.ics     — partner proposals (family key)
    └── tasks/                 — assigned kids tasks (family key)
```

## Data Migration & Recovery

When configuring WebDAV or upgrading with existing server data:

1. **Automatic detection**: App detects remote tasks/notes without decrypting them
2. **User choice**: Dialog offers to import (re-encrypt with new key) or cleanup (delete old data)
3. **Key recovery**: Export/import recovery keys in Settings **Back-up & Herstel** for multi-device access

The recovery key is your personal AES-256 key in JSON format. Export it to enable:
- Importing on new devices to access old encrypted data
- Disaster recovery if the local key is lost
- Manual backup of your encryption key

## Backlog

- "Assign to child" UI in task detail
- Parent approval screen for kids-completed tasks
- Activity history and XP tracking
