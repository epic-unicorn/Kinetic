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

- **Personal tasks** — quick-add, swipe-to-complete, priorities, categories, due dates, recurrence, and **smart reminder chips** that propose contextual times from title and history. Enabling a reminder defaults to **one hour from now, rounded up to the next half hour**; the time dialog focuses the hour field so you can type immediately
- **Partner coordination** — QR pairing, encrypted task proposals, accept/decline flow; partner-targeted suggestions require an explicit **Naar partner** action after a **Dit ziet je partner** preview (nothing is auto-sent)
- **Kids tasks** — assign tasks per child with configurable XP; the kids app syncs assignments and awards XP on completion
- **Notes** — markdown notes, personal or shared with partner; list rows show title, reminder, and shared badge only (body is hidden). Same bottom-sheet editor layout as tasks
- **AI suggestions** — fully offline heuristic engine (habits, calendar, stale open tasks, seasonal history, privacy-preserving partner hints) with human-readable explanations
- **Themes** — Licht, Zand, Schemer, Nacht (OLED)
- **Connection-aware send** — partner and kids listed individually with WebDAV presence status before forwarding
- **Encryption** — 12-word BIP-39 vault; derived AES-256-GCM key in device secure storage. Same phrase for WebDAV and `.kvault` backup
- **WebDAV sync** — optional; bring your own server, no vendor backend
- **Backup & restore** — encrypted `.kvault` (no key in the file). Restore with the 12 words, from a file **or** from WebDAV

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

1. **Instellingen → Familie → Partner** → share QR (12 family words + entropy QR)
2. Partner scans **or** types the 12 words and confirms the fingerprint
3. Proposals sync automatically via WebDAV

### Kids enrollment

1. **Instellingen → Familie → Kinderen** → generate QR with family key + kid UUID (no WebDAV password)
2. Child device scans the QR and types the WebDAV password once
3. Parent sends tasks targeted to that child's UUID

Ship parent **and** kids 0.3.0 together: an old kids app would save an empty password from a new QR.

The **Familie** screen shows **Voorstellen** and **Kinderen** tabs only when a partner is paired or kids are enrolled. Shared notes require partner pairing.

## AI Suggestion Engine

A fully offline, heuristic-based engine surfaces task suggestions in the parent **Taken** screen. No API calls — runs entirely on-device.

An empty run does **not** start the 24-hour throttle, so creating tasks can surface hints on the next open. After at least one suggestion is created, that path waits 24 hours.

| Detector | Trigger | Target | What the partner sees |
|---|---|---|---|
| **Habit** | Same non-recurring title completed ≥ 2× and the median interval is overdue, **or** one completion of a strong keyword (e.g. boodschappen) after ≥ 14 days | You | — |
| **Calendar** | Month-based prompts with no history required (belasting in March, schoolspullen in August, kerst in December) | You | — |
| **Stale** | Open task older than 7 days with no due date or reminder | You (sets a reminder on the existing task) | — |
| **Seasonal** | Task completed in the same calendar month in a prior year | You | — |
| **Partner complement** | Keywords in **your** open tasks (including private) | Partner suggestion | A **generic** template only — never the private title or notes |
| **Load balance** | ≥ 3 open tasks in the same category (private included; `other` needs ≥ 5) | Partner suggestion | A generic “kan jij iets in [categorie] oppakken?” line |

Partner hints are capped at one per keyword-family per 14 days. **Naar partner** always shows **Dit ziet je partner** before anything is sent. Nothing is auto-sent.

Suggestions appear in a banner on the **Privé** tab and in structured sections on **Voorstellen** (**Voor jou** / **Voor partner** / **Van partner**). See [`apps/parent/docs/SMART_FEATURES.md`](apps/parent/docs/SMART_FEATURES.md) for reminder chips and send-sheet details.

## Encryption

| Key | Scope |
|---|---|
| **Personal vault** | 12 English BIP-39 words → PBKDF2 seed → 32-byte AES-256-GCM key. Encrypts personal tasks, notes, `.kvault` backups, and `vault.meta`. 16-byte entropy may be stored on-device so Settings can show the words again behind the device lock. Paper remains the only off-device backup. |
| **Family key** | 12 BIP-39 words → derived AES-256-GCM key. QR carries 16-byte entropy (no WebDAV password). Fingerprint in settings. Recovered via `family.key.enc` after a personal vault restore. A 0.2.x random family key is kept as-is (no words until you create a new family vault). |
| **Kid UUID** | Per enrolled child device for task targeting |

On first launch the parent app asks **Nieuwe kluis** or **Kluis herstellen**. Restore is either a `.kvault` file plus the 12 words (offline) **or** WebDAV login plus the same 12 words (no file). After reinstall, the same phrase unlocks the server copy via `/kinetic/{user}/vault.meta`.

Export never includes the mnemonic, the raw key, or the WebDAV password. Settings can **verify** the phrase without showing the words, or **show** them after Face ID / fingerprint / PIN.

### Upgrade from 0.2.x

A random 32-byte AES key cannot be turned into a BIP-39 mnemonic. On first 0.3 launch the app detects a stored personal key without `kinetic_vault_ready` and asks for a **new** 12-word phrase. Local SQLite stays. Personal tasks/notes are marked dirty so the next WebDAV sync re-encrypts them; `vault.meta` is rewritten. Remote blobs that are never overwritten stay undecryptable (pull already skips MAC failures).

The **family key is not rotated** (that would break partner and kids). Old random family keys keep working; they have no words until you explicitly create a new family vault and re-enroll.

A one-time **Oude back-up (.kbak2)** path on the welcome screen restores the 0.2 file (plaintext key in JSON) and then uses the same rotate-to-mnemonic flow. New backups are `.kvault` only.

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
