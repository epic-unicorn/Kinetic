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
  ├── secure/       — secure key-value storage (from kinetic_webdav)
  └── main.dart     — simple home screen, placeholder
```

### Architecture (Kinetic v2 — WebDAV-first)

**Local-first, offline-capable:**
- Parent app: local SQLite database (Drift) for personal tasks and notes
- Kids app: placeholder (tasks pushed from parent in future phases)
- All data stored encrypted locally on device

**Optional remote sync:**
- Parent app can optionally connect to a WebDAV server (Nextcloud, Apache, etc.)
- Sync is user-initiated (no automatic cloud agent)
- All encryption/decryption happens on-device; server never sees plaintext

**No centralized hub:**
- No CouchDB
- No mDNS discovery
- No enrollment system
- Pure WebDAV for family-shared data

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

Currently a placeholder. Task pushing from parent app is planned for a future phase.

---

## Partner Communication (Phase 11)

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

## Codec — how document encryption works

`packages/sync/lib/src/crypto/document_codec.dart` wraps AES-256-GCM:

- **Encrypt**: serialise doc to JSON → generate a random 12-byte nonce → `AesGcm.with256bits().encrypt(plaintext, nonce, secretKey)` → store `{nonce, ciphertext, mac}` as a CouchDB document.
- **Decrypt**: reverse — extract nonce, call `.decrypt()`, parse JSON back to `Map<String,dynamic>`.
- The `meshKey` (32 bytes) is the AES secret. It never leaves the device and is never sent to CouchDB.

To test the codec in isolation:

```bash
cd packages/sync
flutter test test/crypto/document_codec_test.dart --reporter=expanded
```

---

## CRDT merge rules

`CouchSyncService._merge()` (in `packages/sync`) resolves conflicts deterministically:

| Field | Winner |
|---|---|
| `crdtVersion` higher | that document wins unconditionally |
| `crdtVersion` equal | `updatedAt` timestamp — later wins |
| All equal | local document is kept (safety net) |

This covers `Task` (last-write-wins on `updatedAt`) and `FamilyPlan` (monotonic `crdtVersion`).
