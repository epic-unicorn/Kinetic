# Kinetic Link — Kids App

The child-facing Flutter app for Kinetic Link. Children see tasks assigned by a parent, mark them done, and earn XP (display coming in Phase 14).

## Screens

| Screen | Description |
|---|---|
| **Home (KidsHomeScreen)** | Two sections — "Nog te doen" (pending) and "Afgerond" (completed). Each task shows title, category icon, priority badge, and due date. Tap to open detail. Sync button in the app bar triggers a manual WebDAV pull/push. |
| **Task detail (KidsTaskDetailScreen)** | Full-screen view with category, priority, due date, XP reward, and notes. "Klaar!" button marks the task complete and queues a sync push. |

## How sync works

The kids app reads its WebDAV credentials from the same secure storage that the parent app writes to (assuming the kids device was set up by scanning/copying the parent's configuration). On startup and on every app resume:

1. `WebDavConfigRepository` reads server URL + credentials from secure storage
2. `KidsSyncOrchestrator` pulls all files from `/kinetic/shared/tasks/` (family-key encrypted)
3. Assigns tasks are merged into the local SQLite database (Last-Write-Wins on `updatedAt`)
4. Any locally-completed tasks are pushed back to WebDAV

The local database (`AppDatabase` via Drift) is the source of truth for the UI.

## Running in development

```bash
cd apps/kids
flutter run
```

No `--dart-define` flags required. All secrets are stored at runtime via secure storage (`FlutterSecureKeyValueStore`).

See [docs/development.md](../../docs/development.md) for full setup instructions.

## Building a release APK

```bash
cd apps/kids
flutter clean
flutter pub get
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

No secrets are embedded in the binary. See [docs/deployment.md](../../docs/deployment.md) for distribution instructions.

## Running tests

```bash
flutter test
```

34 tests covering: database CRUD, iCal↔task conversion, priority mapping, LWW merge logic, soft-delete tombstones, dirty-row tracking, and widget smoke tests.

## Data model

| Field | Type | Notes |
|---|---|---|
| `id` | String (UUID) | iCal UID, set by parent |
| `parentId` | String | Identifies which parent assigned it |
| `title` | String | Task title |
| `category` | TaskCategory | household / school / health / shopping / entertainment / other |
| `priority` | TaskPriority | urgent / high / normal / low |
| `dueDate` | DateTime? | Optional deadline |
| `isCompleted` | bool | Set locally by child |
| `xpReward` | int | XP to award on completion (stored; display in Phase 14) |
| `syncState` | String | clean / dirty / deleted — drives WebDAV push |
| `webdavEtag` | String? | Server ETag for conflict detection |

## Dependencies

| Package | Role |
|---|---|
| `kinetic_webdav` | WebDAV client, iCal parser, AES-256-GCM encryption, `SecureKeyValueStore` |
| `drift` / `drift_flutter` | Local SQLite persistence (assigned tasks) |
| `flutter_secure_storage` | Android Keystore-backed key-value storage |

## Backlog (Phase 14+)

- XP total display in the UI header
- Parent approval workflow (task stays pending until parent approves)
- Activity badges and achievement unlocks
- Family leaderboard
