# Kinetic Link — Parent App

The parent-facing Flutter app for Kinetic Link. Parents manage their own personal tasks, promote them to kids missions with an XP reward, balance workloads with their partner, and approve completed tasks.

## Screens

| Screen | Description |
|---|---|
| **Tasks** | Personal task manager backed by a local SQLite database (Drift). Smart lists (Today, Scheduled, Flagged, All) plus user-created lists. Quick-add bar, swipe-to-complete, priority flags, due dates, and recurrence rules. |
| **Approvals** | Pending task approvals and open help tickets from children. One-tap approve (grants XP) or reject (sends task back to in-progress). |
| **Partner** | Load-balancing snapshot comparing this parent's open-task count to their partner's. Synced via the shared CouchDB store. |
| **Settings** | Device identity and QR pairing code. Displays sync status (idle / syncing / error). |

### Convert to Mission

From the **Tasks** screen, any personal task can be promoted to a kids mission:

1. Open the task detail sheet and tap **⚡ Convert to mission**.
2. Choose an XP reward (5–100) and optionally pre-assign it to a child.
3. Confirm — the mission is written to the shared CouchDB store and syncs to child devices. The personal task gains a gold **⚡ Mission** badge and a `kidsTaskId` backlink.

## Running in development

```bash
cd apps/parent
flutter run
```

No `--dart-define` required for dev — fallback credentials and mesh key are baked in and match `hub/.env.example`.

See [docs/development.md](../../docs/development.md) for full setup instructions.

## Building a release APK

```bash
flutter build apk --release \
  --dart-define=MESH_KEY_HEX=<64-char-hex-key> \
  --dart-define=COUCH_USER=<username> \
  --dart-define=COUCH_PASSWORD=<password>
```

See [docs/deployment.md](../../docs/deployment.md) for key generation and full deployment instructions.

## Running tests

The parent app shell currently has a smoke-test widget test only. Unit-level logic is tested in the shared packages.

```bash
flutter test
```

## Dependencies

| Package | Role |
|---|---|
| `kinetic_core` | Device identity, QR pairing, Task/FamilyPlan models |
| `kinetic_sync` | mDNS discovery and encrypted CouchDB sync |
| `kinetic_support` | ApprovalService, TicketService, XpLedger |
| `drift` / `drift_flutter` | Local SQLite persistence for personal tasks |
| `flutter_secure_storage` | Android Keystore / iOS Keychain-backed identity storage |
| `cryptography_flutter` | Hardware-accelerated AES-256-GCM |
| `qr_flutter` | QR code rendering for the pairing screen |
