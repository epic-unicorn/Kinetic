<p align="center">
  <img src="public/logo-mark.svg" alt="Kinetic Link logo" width="96" height="96" />
</p>

<h1 align="center">Kinetic Link</h1>

<p align="center">
  <strong>Tasks. Notes. Family.</strong><br>
  Local-first family task management — encrypted on your device, optional WebDAV sync.
</p>

<p align="center">
  Flutter · AES-256-GCM · Offline-first · No account · No telemetry
</p>

---

Kinetic Link helps parents run household tasks without accounts, without telemetry, and without cloud lock-in. Manage personal tasks and notes locally, coordinate with your co-parent via proposals, assign chores to kids with XP rewards, and optionally sync everything to your own WebDAV server.

Two Flutter apps share crypto and sync logic in `packages/webdav` (AES-256-GCM, iCal, WebDAV client).

## Features

- **Personal tasks** — quick-add, swipe-to-complete, priorities, categories, due dates, recurrence, and **smart reminder chips** that propose contextual times from title and history
- **Partner coordination** — QR pairing, encrypted task proposals, accept/decline flow; partner-targeted AI suggestions require an explicit **Naar partner** action (nothing is auto-sent)
- **Kids tasks** — assign tasks per child with configurable XP; the kids app syncs assignments and awards XP on completion
- **Notes** — markdown notes, personal or shared with partner; same bottom-sheet editor layout as tasks
- **AI suggestions** — fully offline heuristic engine (habits, seasonal patterns, partner complement, load balance) with human-readable explanations
- **Connection-aware send** — partner and kids listed individually with WebDAV presence status before forwarding
- **Encryption** — personal key per parent device; family key via QR for proposals, shared notes, and kids tasks
- **WebDAV sync** — optional; bring your own server, no vendor backend
- **Backup & restore** — encrypted `.kbak2` backup including personal key and database

## Apps

| App | Platforms | Description |
|---|---|---|
| [`apps/parent`](apps/parent) | Android, iOS | Task manager, partner proposals, notes, kids overview, WebDAV config |
| [`apps/kids`](apps/kids) | Android | Assigned tasks synced from parent; children mark complete and earn XP |

## Tech Stack

| Layer | Choice |
|---|---|
| Apps | Flutter (parent + kids) |
| Local DB | Drift (SQLite) |
| Crypto & sync | `packages/webdav` — AES-256-GCM, iCal, WebDAV client |
| Monorepo | Melos |
| Tests | `flutter test` per package |

## Getting Started

```bash
dart pub global activate melos
melos bootstrap
melos run test        # run all tests
cd apps/parent && flutter run
```

No server required — the app works fully offline. Configure WebDAV in **Instellingen** to enable sync and family pairing.

### Build a release APK

```bash
cd apps/parent   # or apps/kids
flutter build apk --release
```

CI builds and signs both APKs on every push to `main`, `develop`, or `feature/**`, and on any `v*` tag (see [`.github/workflows/build-release.yml`](.github/workflows/build-release.yml)).

## Family Setup

### Partner pairing

1. **Instellingen → Familie → Partner** → share QR code
2. Partner scans QR on their device
3. Proposals sync automatically via WebDAV

### Kids enrollment

1. **Instellingen → Familie → Kinderen** → generate QR with family key + kid UUID
2. Child device scans QR in the kids app
3. Parent sends tasks targeted to that child's UUID

The **Familie** screen shows **Voorstellen** and **Kinderen** tabs only when a partner is paired or kids are enrolled. Shared notes require partner pairing.

## AI Suggestion Engine

A fully offline, heuristic-based engine surfaces task suggestions in the parent **Taken** screen. No API calls — runs entirely on-device, at most once per 24 hours.

| Detector | Trigger | Target |
|---|---|---|
| **Habit** | Non-recurring task completed ≥ 2× and median interval exceeded by ≥ 80% | You |
| **Seasonal** | Task completed in the same calendar month in a prior year | You |
| **Partner complement** | You accepted a partner proposal matching keywords (vakantie, sport, school, …) | Partner (via suggestion) |
| **Load balance** | ≥ 3 open non-private tasks in the same category | Partner (via suggestion) |

Suggestions appear in a banner on the **Privé** tab and in structured sections on **Voorstellen** (**Voor jou** / **Voor partner** / **Van partner**). See [`apps/parent/docs/SMART_FEATURES.md`](apps/parent/docs/SMART_FEATURES.md) for reminder chips and send-sheet details.

## Encryption

| Key | Scope |
|---|---|
| **Personal key** | Unique per parent device; personal tasks & notes |
| **Family key** | Shared via QR; proposals, shared notes, assigned kids tasks |
| **Kid UUID** | Per enrolled child device for task targeting |

## Releases

Push a version tag to trigger a GitHub Release:

```bash
git tag v0.2.0
git push origin v0.2.0
```

This creates **two separate releases**:

- `v0.2.0-kids` — `kinetic-kids-0.2.0.apk`
- `v0.2.0-parent` — `kinetic-parent-0.2.0.apk`

Each release includes a `sha256.txt` checksum file.

### Verifying release APKs

#### 1. APK file integrity (SHA-256 file hash)

`sha256sum` outputs a continuous lowercase hex string. This matches the value in `sha256.txt` and in the release notes.

```bash
echo "<digest>  kinetic-parent-0.2.0.apk" | sha256sum --check
```

Or manually compare:

```bash
sha256sum kinetic-parent-0.2.0.apk
# compare with the digest listed in sha256.txt
```

#### 2. Signing certificate fingerprint (AppVerifier format)

AppVerifier shows the SHA-256 fingerprint of the **signing certificate** in `AA:BB:CC:DD:...` format (uppercase colon-separated pairs). This differs from the APK file hash above.

The certificate fingerprint is listed in the GitHub Release notes under **Certificate Fingerprint (AppVerifier)**.

```bash
keytool -printcert -jarfile kinetic-parent-0.2.0.apk
# look for the SHA256: line — format is AA:BB:CC:DD:...
```
