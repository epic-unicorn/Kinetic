# Development guide

This document covers setting up a local development environment, running tests, linting, and extending the monorepo.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter | ≥ 3.19.3 | [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install) |
| Dart | ≥ 3.3.0 (bundled with Flutter) | — |
| Melos | ≥ 7.4.1 | `dart pub global activate melos` |
| Android SDK | API 24+ | bundled with Android Studio |

> **iOS builds** (parent app only) additionally require Xcode ≥ 15 and a macOS host.

---

## First-time setup

```bash
# Clone the repo
git clone <repo-url>
cd Kinetic

# Install all package dependencies in one shot
melos bootstrap
# Equivalent to running `flutter pub get` in every package and app.

# Run tests to verify setup
melos run test
```

---

## Project structure

```
packages/webdav   — WebDAV client, iCal serializer, encryption, sync service
apps/parent       — parent Flutter app (Android + iOS)
  lib/
  ├── db/           — Drift AppDatabase (personal tasks, notes)
  ├── todo/         — task & note models, repositories, screens, widgets
  ├── partner/      — partner communication & proposal sync
  ├── settings/     — app settings, WebDAV configuration, theme
  ├── sync/         — WebDAV synchronization orchestrator
  ├── theme/        — Material 3 design system, colors, typography
  ├── support/      — notification service
  └── main.dart     — app entry point
apps/kids         — kids Flutter app (Android)
  lib/
  ├── db/           — Drift AppDatabase (assigned tasks)
  ├── task/         — task models, repository, screens
  ├── sync/         — WebDAV sync orchestrator, config repository
  ├── secure/       — secure key-value storage (from kinetic_webdav)
  └── main.dart     — app entry point
```

### Architecture (Kinetic v2 — WebDAV-first)

**Local-first, offline-capable:**
- Parent app: local SQLite (Drift) for personal tasks and notes
- Kids app: local SQLite (Drift) for assigned tasks received from parent
- All data stored encrypted locally on device

**Optional remote sync:**
- Parent app can optionally connect to a WebDAV server (Nextcloud, Apache, etc.)
- Sync fires on app resume and can be triggered manually from Settings
- All encryption/decryption happens on-device; server never sees plaintext

**No centralized hub:**
- No CouchDB, no mDNS discovery, no enrollment system
- Pure WebDAV for all family-shared data

---

## Running tests

### All packages at once (recommended)

```bash
melos run test
```

### Single package

```bash
cd packages/webdav
flutter test

cd apps/parent
flutter test

cd apps/kids
flutter test
```

### With expanded output

```bash
cd packages/webdav
flutter test --reporter=expanded
```

---

## Linting and static analysis

### All packages at once

```bash
melos run analyze
```

### Single package / app

```bash
cd packages/webdav && flutter analyze
cd apps/parent && flutter analyze
cd apps/kids && flutter analyze
```

All should report **No issues found**.

---

## Running the apps locally

Both apps run standalone without any server dependency.

### Parent app

```bash
cd apps/parent
flutter run
```

The app starts in a state where WebDAV is unconfigured. Navigate to Settings > WebDAV Configuration to optionally connect to a test server.

### Kids app

```bash
cd apps/kids
flutter run
```

The app starts with an empty task list. To receive tasks, the kids device needs WebDAV credentials written into its secure storage — the simplest way is to copy them from a parent device via the Settings screen.

---

## Kids Task Sync (Phase 13)

The kids app syncs assigned tasks via WebDAV using the same `kinetic_webdav` package as the parent app.

### How the sync cycle works

1. `_KidsAppShell.initState()` creates `KidsTaskRepository` then calls `_initSync()`
2. `_initSync()` reads `SyncConfig` from `WebDavConfigRepository` (same secure storage keys the parent writes)
3. If config is present, `KidsSyncOrchestrator` is instantiated
4. `KidsSyncOrchestrator.sync()` is called immediately and again on every `AppLifecycleState.resumed`
5. Sync: pulls files from `/kinetic/shared/tasks/`, decrypts with family key, converts iCal → `KidsTask`, merges (LWW on `updatedAt`), then pushes any dirty rows back

### Sync states

| `syncState` | Meaning |
|---|---|
| `clean` | In sync with server |
| `dirty` | Locally modified (e.g. marked complete), needs push |
| `deleted` | Soft-deleted tombstone, push DELETE then hard-delete |

### iCal encoding

Custom fields are encoded in the iCal `DESCRIPTION` field:

```
{notes};xKineticParentId:{id};xKineticCategory:{cat};xKineticXpReward:{n}
```

Priority maps: `PRIORITY:1` = urgent, `PRIORITY:5` = normal, `PRIORITY:9` = low.

---



The Partner screen enables inter-parent task proposal and family workload management. All communication is encrypted and synced via WebDAV.

### How proposals work

1. **Parent A proposes a task** to Parent B via the Partner screen
2. **Task is sent to WebDAV** at `/kinetic/shared/proposals/{taskId}.ics` (encrypted with family key)
3. **Parent B sees proposal** in Partner screen with options to: **Accept** (creates task in their list), **Snooze** (marked for later), or **Dismiss**
4. **Status changes sync** back to WebDAV, updating both parents' views

### Proposal lifecycle

- **pending** — newly received, awaiting action
- **accepted** — parent accepted; task created in their personal list
- **snoozed** — temporarily deferred; will resurface after configured time
- **dismissed** — explicitly rejected; won't resurface

### Family load metrics  

The Partner screen also displays **family workload metrics**:

- Task count per family member (total non-completed tasks)
- Urgent task count (due within 7 days, not completed)
- Tasks by category breakdown
- Last calculated timestamp

This helps with fair task distribution — you can see if your co-parent is already overloaded before proposing more tasks.

### Services involved

| Service | File | Purpose |
|---|---|---|
| `PartnerProposalRepository` | `lib/partner/services/partner_proposal_repository.dart` | Database CRUD for proposals |
| `PartnerProposalService` | `lib/partner/services/partner_proposal_service.dart` | WebDAV sync of proposals |
| `PartnerLoadRepository` | `lib/partner/services/partner_load_repository.dart` | Workload metrics display |
| `LoadSyncService` | `lib/partner/services/load_sync_service.dart` | WebDAV sync of load metrics |
| `LoadAnalyzer` | `lib/partner/services/load_analyzer.dart` | Calculates own workload |
| `PartnerScreen` | `lib/partner/screens/partner_screen.dart` | UI for proposals + metrics |

### WebDAV file structure

```
/kinetic/shared/
├── proposals/
│   ├── {proposalId}.ics          (VJOURNAL format, family key encrypted)
│   └── ...
└── load/
    ├── {parentId1}.json          (FamilyLoadMetrics, family key encrypted)
    └── {parentId2}.json
```

### Testing proposals locally

1. Run the parent app in development
2. Navigate to **Partner** tab
3. Without a configured WebDAV server, the UI loads with empty proposals
4. With WebDAV configured, proposals sync from `/kinetic/shared/proposals/`

---

## Package dependency graph

```
apps/parent ──► packages/webdav
apps/kids   ──► packages/webdav
```

No circular dependencies.

---

## Code conventions

- **Imports:** All imports use relative paths from the package root.
- **Naming:** Classes use PascalCase, methods/variables use camelCase.
- **State management:** Simple `ValueNotifier` for theme switching; streams (Drift) for database changes.
- **Error handling:** Exceptions logged to stderr; user-facing errors shown via `SnackBar` or `AlertDialog`.
- **Testing:** Unit tests for services; widget tests for screens when feasible.

---

## Build & deployment

See [deployment.md](deployment.md) for building release APKs and distributing to users.

## Adding a new package

1. Create the package:
   ```bash
   flutter create --template=package packages/my_package
   ```

2. Add it to `melos.yaml` — already covered by the `packages/*` glob, no change needed.

3. Add a path dependency in any app or package that uses it:
   ```yaml
   # e.g. apps/parent/pubspec.yaml
   dependencies:
     my_package:
       path: ../../packages/my_package
   ```

4. Run `melos bootstrap` to link everything.

5. Create `packages/my_package/test/` and write tests before shipping.

---

## Package dependency graph
