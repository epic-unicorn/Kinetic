# Development guide

This document covers setting up a local development environment, running tests, linting, and extending the monorepo.

---

## Prerequisites

| Tool | Version | Install |
|---|---|---|
| Flutter | ≥ 3.19.3 | [flutter.dev/docs/get-started/install](https://docs.flutter.dev/get-started/install) |
| Dart | ≥ 3.3.0 (bundled with Flutter) | — |
| Melos | ≥ 7.4.1 | `dart pub global activate melos` |
| Docker + Compose | any recent | [docs.docker.com/get-docker](https://docs.docker.com/get-docker/) — needed only for the hub |
| Android SDK | API 24+ | bundled with Android Studio |

> **iOS builds** additionally require Xcode ≥ 15 and a macOS host (parent app only).

---

## First-time setup

```bash
# Clone the repo
git clone <repo-url>
cd Kinetic

# Install all package dependencies in one shot
melos bootstrap
# Equivalent to running `flutter pub get` in every package and app.
```

---

## Project structure

```
packages/core     — identity, models, pairing
packages/sync     — mDNS, AES-256-GCM, CouchDB replication
packages/support  — approvals, XP ledger, help tickets
apps/parent       — parent Flutter app
  lib/
  ├── db/         — Drift AppDatabase (personal task tables + DAOs)
  ├── todo/
  │   ├── models/    — PersonalTask, TaskList, enums (local-only types)
  │   ├── services/  — TodoRepository, MissionConverterService
  │   ├── screens/   — TasksScreen
  │   └── widgets/   — TaskTile, TaskDetailSheet, ConvertToMissionSheet, QuickAddBar
  ├── partner/    — LoadAnalyzer, LoadSyncService, PartnerScreen
  ├── settings/   — SettingsScreen
  └── support/    — CouchDocumentStore wrapper
apps/kids         — kids Flutter app
hub/              — Docker Compose sync hub
```

> **Personal tasks vs shared tasks** — `PersonalTask` is stored in the device-local Drift SQLite database and never syncs. When a parent promotes a personal task to a kids mission via *Convert to Mission*, `MissionConverterService` creates a `kinetic_core.Task` and upserts it into `CouchDocumentStore`, from where it syncs to child devices on the next heartbeat. The `PersonalTask.kidsTaskId` field stores the backlink.

---

## Running tests

### All packages at once (recommended)

```bash
melos run test
```

Melos executes `flutter test` in every package/app directory that contains a `test/` folder and prints a combined summary.

### Single package

```bash
cd packages/core
flutter test

cd packages/sync
flutter test

cd packages/support
flutter test
```

### With expanded output

```bash
cd packages/core
flutter test --reporter=expanded
```

### Expected results

| Package | Tests | Notes |
|---|---|---|
| `packages/core` | 29 | identity, pairing, models |
| `packages/sync` | 33 | HTTP client, sync service, codec, orchestrator |
| `packages/support` | 38 | approvals, XP ledger, tickets |

---

## Test organisation

```
packages/core/test/
├── helpers/
│   └── in_memory_key_store.dart   ← SecureKeyValueStore stub
├── identity/
│   ├── identity_service_test.dart
│   └── pairing_service_test.dart
└── models/
    └── models_test.dart

packages/sync/test/
├── couch/
│   ├── couch_http_client_test.dart
│   └── couch_sync_service_test.dart
├── crypto/
│   └── document_codec_test.dart
└── helpers/
    ├── fake_mdns_service.dart      ← MdnsDiscoveryService stub
    └── mock_http_client.dart       ← http.Client mock (mocktail)

packages/support/test/
├── models/
│   ├── support_ticket_test.dart
│   └── xp_ledger_test.dart
└── services/
    ├── approval_service_test.dart
    └── ticket_service_test.dart
```

Test helpers follow the convention:
- `helpers/fake_*.dart` — simple manual fakes, no mocking library
- `helpers/mock_*.dart` — mocktail-generated mocks (only in `packages/sync`)

---

## Linting and static analysis

### All packages at once

```bash
melos run analyze
```

### Single package / app

```bash
cd packages/core && flutter analyze --no-fatal-infos
cd apps/parent   && flutter analyze --no-fatal-infos
cd apps/kids     && flutter analyze --no-fatal-infos
```

All three packages and both apps should report **No issues found**.

---

## Running the apps locally

Both apps connect to the hub over mDNS + CouchDB. For local development:

1. Start the hub (see [deployment.md § Running the hub locally](deployment.md#running-the-hub-locally)).
2. Run the app with the dev defaults (mesh key and credentials are baked in as fallback values):

```bash
# Parent app
cd apps/parent
flutter run

# Kids app
cd apps/kids
flutter run
```

The dev mesh key `dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0dev0` is baked into both apps as a fallback — it matches nothing in production (where you supply your own via `--dart-define`).

---

## Package dependency graph

```
apps/parent ──► packages/core
            ──► packages/sync ──► packages/core
            ──► packages/support ──► packages/core

apps/kids   ──► packages/core
            ──► packages/sync
            ──► packages/support
```

There are no circular dependencies. `packages/core` has no internal package dependencies.

---

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
