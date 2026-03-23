# Kinetic Link — Kids App

The child-facing Flutter app for Kinetic Link. Children see their assigned missions and habits, mark them done, earn XP, and raise help tickets to their parents.

## Screen

| Area | Description |
|---|---|
| **XP header** | Displays the child's current XP balance pulled live from the sync store. |
| **Mission list** | All tasks assigned to this device that are not yet completed. Habits complete immediately on tap; missions enter `pendingApproval` and show a "Waiting…" chip until a parent approves. |
| **Ask for help** | FAB opens a dialog to raise a `SupportTicket` with a required title and optional description. Tickets appear in the parent app's Approvals screen. |

## Running in development

```bash
cd apps/kids
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

```bash
flutter test
```

## Task submission logic

The task category determines what happens when a child taps the action button:

| Category | On submit | XP awarded |
|---|---|---|
| `habit` | Status → `completed` immediately | No XP |
| `mission` | Status → `pendingApproval`; parent must approve | On approval |

## Dependencies

| Package | Role |
|---|---|
| `kinetic_core` | Device identity, Task/FamilyPlan models |
| `kinetic_sync` | mDNS discovery and encrypted CouchDB sync |
| `kinetic_support` | TicketService, XpLedger, ApprovalService |
| `flutter_secure_storage` | Android Keystore-backed identity storage |
| `cryptography_flutter` | Hardware-accelerated AES-256-GCM |
