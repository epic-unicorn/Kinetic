# Kinetic Link

Local-first family task management. Parents assign missions and habits to children; kids complete them and earn XP; parents approve and the ledger updates — all over an encrypted peer-to-peer sync layer with no cloud dependency.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Kinetic Link monorepo                 │
│                                                         │
│  apps/parent          apps/kids                         │
│  ┌──────────┐         ┌──────────┐                      │
│  │ Flutter  │         │ Flutter  │                      │
│  │ Parent   │◄───────►│  Kids   │                      │
│  │   App    │  mDNS + │   App   │                      │
│  └────┬─────┘  CouchDB└────┬─────┘                      │
│       │         sync       │                            │
│       └──────┬─────────────┘                            │
│              │                                          │
│         hub/ (Docker Compose)                           │
│         ┌────────────┐                                  │
│         │  CouchDB 3 │ ← encrypted blobs only           │
│         │  + mDNS    │   hub never sees plaintext        │
│         │  advertiser│                                  │
│         └────────────┘                                  │
│                                                         │
│  packages/                                              │
│  ├── core     — Ed25519 identity, models, pairing       │
│  ├── sync     — mDNS discovery, AES-256-GCM, CouchDB    │
│  └── support  — approvals, XP ledger, help tickets      │
└─────────────────────────────────────────────────────────┘
```

### Package responsibilities

| Package | What it does |
|---|---|
| `packages/core` | Ed25519 device identity, QR pairing, `Task` / `FamilyPlan` models |
| `packages/sync` | mDNS discovery (Bonsoir), AES-256-GCM document encryption, CouchDB push/pull, `SyncOrchestrator` |
| `packages/support` | `ApprovalService`, `XpLedger`, `TicketService`, `DocumentStore` interface |
| `apps/parent` | Parent dashboard — pair devices, approve tasks, view help tickets |
| `apps/kids` | Child home screen — view missions, mark tasks done, ask for help |
| `hub/` | Docker Compose: CouchDB 3 + one-shot init + mDNS advertiser sidecar |

### Key design choices

- **Local-first** — all data lives on-device; the hub is a dumb encrypted relay.  The app works offline and syncs opportunistically.
- **Encrypted at rest and in transit** — AES-256-GCM with a family mesh key baked in at build time.  The hub stores only ciphertext and never holds the key.
- **No account / cloud sign-up** — devices pair via QR code over the local network.  The mesh key is distributed as a `--dart-define` build flag.
- **CRDT merge** — `Task` conflicts resolve by `updatedAt` (last-write-wins); `FamilyPlan` conflicts by `crdtVersion`.

---

## Repository layout

```
Kinetic/
├── melos.yaml               ← Melos monorepo config
├── README.md                ← this file
├── docs/
│   ├── development.md       ← local dev setup, testing, linting
│   └── deployment.md        ← building APKs, running the hub, key management
├── apps/
│   ├── parent/              ← Flutter parent app (Android + iOS)
│   └── kids/                ← Flutter kids app (Android)
├── hub/
│   ├── docker-compose.yml   ← CouchDB + mDNS advertiser
│   ├── .env.example         ← credential and key templates
│   ├── init/
│   │   └── setup-couch.sh   ← one-shot DB initialisation script
│   └── advertise/
│       ├── advertise.py     ← Python/zeroconf mDNS advertiser
│       ├── Dockerfile
│       └── requirements.txt
└── packages/
    ├── core/
    ├── sync/
    └── support/
```

---

## Quick start

Full instructions are in [docs/development.md](docs/development.md).  The short version:

```bash
# 1. Prerequisites: Flutter ≥3.19, Dart ≥3.3, Melos, Docker
dart pub global activate melos

# 2. Bootstrap all packages
melos bootstrap

# 3. Run all tests
melos run test

# 4. Start the hub (Linux / Raspberry Pi)
cd hub
cp .env.example .env   # edit credentials
docker compose up -d
```

---

## Test coverage summary

| Package | Tests |
|---|---|
| `packages/core` | 29 |
| `packages/sync` | 33 |
| `packages/support` | 38 |
| **Total** | **100** |

Run `melos run test` from the repo root to execute all 100 tests.

---

## Further reading

- [Development guide](docs/development.md) — setup, testing, adding a new package
- [Deployment guide](docs/deployment.md) — building release APKs, running the hub, key rotation
