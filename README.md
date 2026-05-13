# Kinetic Link

Local-first family task management. Parents manage encrypted tasks and notes locally, coordinate with co-parents via proposals, and manage children's assigned tasks — all with optional WebDAV sync. No accounts, no telemetry, no cloud lock-in.

## Apps

| App | Platforms | Description |
|---|---|---|
| `apps/parent` | Android, iOS | Task manager, partner coordination (proposals), notes, child task overview, WebDAV config |
| `apps/kids` | Android | Assigned tasks synced from parent via WebDAV; children mark tasks complete and earn XP |

Shared crypto/sync logic lives in `packages/webdav` (AES-256-GCM, iCal, WebDAV client).

## Architecture Overview

### Encryption
- **Personal Key**: Unique per parent device; encrypts personal tasks & notes
- **Family Key**: Shared across family devices via QR pairing; encrypts proposals, shared notes, assigned tasks
- **Kid UUID**: Each enrolled child device receives unique ID for task targeting

### Family Connections
- **Partner pairing**: Share QR code with partner to sync proposals; marked via `kinetic_partner_paired` flag
- **Kids enrollment**: Parent generates QR with family key + kid UUID; kid device scans to enroll
- **Familie screen**: Conditionally shows "Voorstellen" (proposals) and "Kinderen" (kids tasks) tabs based on what's connected

### XP for Child Tasks
When sending a task to children via "Stuur naar kinderen", the parent sets an XP reward (default 10). The XP value is stored on the task and included in the synced iCal item (`xKineticXpReward` custom property). The kids app awards this XP when the child marks the task complete.

### AI Suggestion Engine (Parent app)
A fully offline, heuristic-based engine that surfaces task suggestions in the **Taken** screen. No API calls or external models — runs entirely on-device.

The engine runs at most once per 24 hours and executes four detectors:

| Detector | Trigger | Target |
|---|---|---|
| **Habit** | Non-recurring task completed ≥ 2× and median interval exceeded by ≥ 80% | You |
| **Seasonal** | Task completed in the same calendar month in a prior year | You |
| **Partner complement** | You accepted a partner proposal whose title matches a keyword (vakantie, sport, school, …) | Partner (auto-proposal) |
| **Load balance** | ≥ 3 open non-private tasks in the same category | Partner (auto-proposal) |

Suggestions appear in a banner above the task list. Each card can be accepted (creates a task), sent to partner, dismissed, or snoozed (7 days). Suggestions are stored locally in the `AiSuggestions` table and never synced.

## Quick start

```bash
dart pub global activate melos
melos bootstrap
melos run test        # run all tests
cd apps/parent && flutter run
```
No server required — the app works fully offline. Configure WebDAV in Settings to enable sync and pairing.

## Building a release APK

```bash
cd apps/parent   # or apps/kids
flutter build apk --release
```

The GitHub Actions workflow (`.github/workflows/build-release.yml`) builds and signs both APKs on every push to `main`, `develop`, or `feature/**` branches, and on any `v*` tag push.

### Creating a release

Push a version tag to trigger a GitHub Release:

```bash
git tag v0.2.0
git push origin v0.2.0
```

This creates **two separate releases**:
- `v0.2.0-kids` — contains `kinetic-kids-0.2.0.apk`
- `v0.2.0-parent` — contains `kinetic-parent-0.2.0.apk`

Each release includes a `sha256.txt` checksum file.

### Verifying release APKs

There are two separate things you can verify — choose the right one for your use case:

#### 1. APK file integrity (SHA-256 file hash)

`sha256sum` outputs a continuous lowercase hex string (e.g. `abc123def456...`). This matches the value in `sha256.txt` and in the release notes.

After downloading the APK and its `sha256.txt` from a GitHub Release:

```bash
echo "<digest>  kinetic-parent-0.2.0.apk" | sha256sum --check
```

Or manually compare:

```bash
sha256sum kinetic-parent-0.2.0.apk
# compare with the digest listed in sha256.txt
```

#### 2. Signing certificate fingerprint (AppVerifier format)

AppVerifier and tools like `keytool` show the SHA-256 fingerprint of the **signing certificate** in `AA:BB:CC:DD:...` format (uppercase colon-separated pairs). This is a different value from the APK file hash above.

The certificate fingerprint is listed in the GitHub Release notes under **Certificate Fingerprint (AppVerifier)**.

To extract it yourself from the downloaded APK:

```bash
keytool -printcert -jarfile kinetic-parent-0.2.0.apk
# look for the SHA256: line — format is AA:BB:CC:DD:...
```