# Kinetic Link

**Local-first family task management.** Parents maintain encrypted personal to-do lists on their devices, with optional syncing to a WebDAV server (Nextcloud, Apache, etc.) for shared family data. No cloud lock-in, no account sign-up, no data sent to third parties.

---

## Architecture

```
┌──────────────────────────────────────────────────────────┐
│           Kinetic Link v2 (WebDAV-first)                │
│                                                          │
│  apps/parent (Android + iOS)                             │
│  ├── Personal tasks/notes (SQLite, local-only)           │
│  ├── Optional WebDAV sync (encrypted)                    │
│  └── Material 3 UI, dark/light/custom themes             │
│                                                          │
│  apps/kids (Android)                                     │
│  ├── Assigned task sync via WebDAV (family key)          │
│  ├── Task completion with XP foundation                  │
│  └── Material 3 UI, dark theme                          │
│                                                          │
│  packages/webdav (shared)                                │
│  ├── WebDAV client (HTTP)                                │
│  ├── iCal serializer (RFC 5545)                          │
│  ├── AES-256-GCM encryption (per-user + family key)      │
│  └── SecureKeyValueStore (platform-specific)             │
│                                                          │
│  (Optional) WebDAV server — user-controlled              │
│  └── No dependency — app works fully offline             │
└──────────────────────────────────────────────────────────┘
```

### Design philosophy

- **Local-first** — all data stored locally by default. Users control whether to opt into remote sync.
- **Zero cloud** — no cloud service, no telemetry, no accounts. Sync is to user-selected WebDAV server only.
- **Encrypted everywhere** — AES-256-GCM encryption on-device before any network transmission.
- **Simple credentials** — family sharing uses WebDAV username/password; family encryption key derived via PBKDF2.
- **Offline-capable** — full app functionality works with no internet connection.
- **Material 3 design** — modern Flutter UI with light/dark/custom theme support.

---

## Repository layout

```
Kinetic/
├── README.md                ← this file
├── melos.yaml               ← Melos monorepo config
├── docs/
│   ├── development.md       ← setup, testing, running locally
│   └── deployment.md        ← building release APKs, WebDAV setup
├── apps/
│   ├── parent/
│   │   ├── lib/
│   │   │   ├── db/          ← Drift schema (personal tasks/notes)
│   │   │   ├── todo/        ← task & note models, repos, screens
│   │   │   ├── partner/     ← partner communication (future)
│   │   │   ├── settings/    ← app prefs, WebDAV config, theme
│   │   │   ├── sync/        ← WebDAV orchestrator
│   │   │   ├── theme/       ← Material 3 design system
│   │   │   └── main.dart
│   │   ├── test/            ← widget tests
│   │   └── pubspec.yaml
│   │
│   └── kids/
│       ├── lib/
│       │   ├── db/          ← Drift schema (assigned tasks)
│       │   ├── task/        ← task models, repository, screens
│       │   ├── sync/        ← WebDAV sync orchestrator
│       │   ├── secure/      ← platform-specific key storage
│       │   └── main.dart
│       ├── test/
│       └── pubspec.yaml
│
└── packages/
    └── webdav/
        ├── lib/
        │   ├── src/
        │   │   ├── client/      ← HTTP WebDAV client
        │   │   ├── ical/        ← RFC 5545 serializer
        │   │   ├── crypto/      ← AES-256-GCM + PBKDF2
        │   │   ├── sync/        ← sync service
        │   │   └── models/
        │   └── kinetic_webdav.dart
        ├── test/
        └── pubspec.yaml
```

---

## Features

### Parent App ✅

- ✅ **Local task storage** — SQLite via Drift, organized by list/category
- ✅ **Material 3 UI** — light mode, dark mode, custom theming
- ✅ **Notes** — markdown-capable, shared/personal, local or WebDAV-synced
- ✅ **Optional WebDAV sync** — Nextcloud, Apache, or any RFC 4918 server
- ✅ **Encryption** — AES-256-GCM per-device + family-shared encryption
- ✅ **Partner communication** — task proposals, snooze/accept/dismiss workflow
- ✅ **Family load metrics** — workload tracking for fair task distribution
- ⏳ **Kids task conversion** — planned for Phase 14+

### Kids App ✅

- ✅ **Task list from parent** — assigned tasks synced via WebDAV (family key encrypted)
- ✅ **Task completion** — kids mark tasks done, status syncs back to parent
- ✅ **XP foundation** — XP reward stored per task (display + approval UI in backlog)
- ✅ **Material 3 UI** — dark theme, task detail screen, sync status indicator

---

## Quick start

Full instructions in [docs/development.md](docs/development.md). Short version:

```bash
# 1. Prerequisites
dart pub global activate melos
# (Flutter 3.19+, Dart 3.3+, Android SDK)

# 2. Bootstrap
melos bootstrap

# 3. Test (optional)
melos run test
melos run analyze

# 4. Run
cd apps/parent && flutter run
# or
cd apps/kids && flutter run
```

**No server required** — the app works fully offline. Optionally configure WebDAV in Settings to enable syncing.

---

## Building for release

See [docs/deployment.md](docs/deployment.md) for:
- Building signed APKs
- Optional WebDAV server setup (Nextcloud, Apache, etc.)
- Security & privacy notes

---

## Project status

| Phase | Feature | Status |
|---|---|---|
| 1–6 | Foundation (pairing, sync, approvals, kids app, enrollment, docker hub) | ✅ Archived (v1) |
| 7–11 | WebDAV migration, encryption, WebDAV sync, partner proposals, notes | ✅ Complete |
| 12 | Material 3 re-theme | ✅ Complete |
| 13 | Kids task sync (WebDAV pull/push, LWW merge, XP foundation) | ✅ Complete |
| 14 | XP display + gamification UI, parent approval workflow for kids tasks | 📋 Backlog |
| 15 | "Assign to child" UI in parent task detail | 📋 Backlog |
| 16 | Activity badges, family leaderboard | 📋 Backlog |

---

## Further reading

- [Development guide](docs/development.md) — setting up locally, running tests
- [Deployment guide](docs/deployment.md) — building releases, WebDAV server guide

---

## License

TBD
