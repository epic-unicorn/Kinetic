# Kinetic Link — Parent App

The parent-facing Flutter app for Kinetic Link. Parents manage personal tasks and notes, balance workload with their partner via task proposals, and configure optional WebDAV sync.

## Screens

| Screen | Description |
|---|---|
| **Taken (Tasks)** | Personal task manager backed by local SQLite (Drift). Quick-add bar, swipe-to-complete, priority flags, category, due dates, and recurrence rules (none/daily/weekly/monthly/yearly). |
| **Partner** | Two-panel view: (1) incoming task proposals from co-parent with accept/snooze/dismiss; (2) family workload metrics showing task counts per person for fair distribution. |
| **Notities (Notes)** | Markdown notes, personal or shared. Inline markdown preview toggle. Synced to WebDAV when configured. |
| **Instellingen (Settings)** | WebDAV server URL, username, password, Test Connection, personal key recovery export, theme selector (light/dark/custom). |

## Running in development

```bash
cd apps/parent
flutter run
```

No `--dart-define` flags required. All secrets are stored at runtime via secure storage.

See [docs/development.md](../../docs/development.md) for full setup instructions.

## Building a release APK

```bash
cd apps/parent
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

For iOS:

```bash
flutter build ipa
```

No secrets embedded in the binary. See [docs/deployment.md](../../docs/deployment.md) for full instructions.

## Running tests

```bash
flutter test
```

107 tests covering: task CRUD, note repository, partner proposal lifecycle, load metrics, WebDAV sync orchestration, settings persistence, and widget smoke tests.

## Architecture

```
Apps/parent/lib/
├── db/           — Drift AppDatabase (PersonalTasks + PersonalNotes tables)
├── todo/         — task & note models, repositories, screens, widgets
├── partner/      — proposal + load metrics models, repositories, screens, services
├── settings/     — app settings, WebDAV config screen, theme preference
├── sync/         — SyncOrchestrator (WebDAV pull/push, LWW merge)
├── theme/        — Material 3 color schemes, typography scale
├── support/      — ParentNotificationService
└── main.dart     — app entry point, _RootShellState, lifecycle sync
```

### WebDAV file structure

```
/kinetic/{username}/
├── tasks/personal.ics      — personal tasks (personal key)
├── tasks/shared.ics        — tasks shared with kids (family key)
├── notes/personal.ics      — personal notes (personal key)
├── notes/shared.ics        — shared notes (family key)
└── shared/
    ├── load/{username}.json        — workload metrics (family key)
    ├── proposals/{id}.ics          — partner proposals (family key)
    └── tasks/                      — assigned kids tasks (family key)
```

## Dependencies

| Package | Role |
|---|---|
| `kinetic_webdav` | WebDAV client, iCal parser/serializer, AES-256-GCM encryption, `SecureKeyValueStore` |
| `drift` / `drift_flutter` | Local SQLite persistence (personal tasks and notes) |
| `flutter_markdown` | Markdown rendering in the Notes screen |
| `flutter_secure_storage` | Android Keystore / iOS Keychain-backed storage |
| `flutter_local_notifications` | Reminder notifications |

## Backlog (Phase 14+)

- "Assign to child" UI in task detail (sends task to `/kinetic/shared/tasks/` for kids app to pull)
- Parent approval screen for kids-completed tasks
- Activity history and XP tracking
