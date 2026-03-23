# Kinetic Link — Parent App

The parent-facing Flutter app for Kinetic Link. Parents pair their device, assign missions and habits to children, approve completed tasks, and monitor XP progress.

## Screens

| Screen | Description |
|---|---|
| **Pair** | Shows a QR code encoding this device's identity. Kids scan it to register as a family member. Displays a sync status banner (idle / syncing / error). |
| **Approvals** | Pending task approvals and open help tickets from children. One-tap approve (grants XP) or reject (sends task back to in-progress). |

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
| `flutter_secure_storage` | Android Keystore / iOS Keychain-backed identity storage |
| `cryptography_flutter` | Hardware-accelerated AES-256-GCM |
| `qr_flutter` | QR code rendering for the pairing screen |
