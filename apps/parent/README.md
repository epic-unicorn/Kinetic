# Kinetic Link — Parent App

Parent-facing Flutter app. Manage personal tasks and notes locally, coordinate with your co-parent via task proposals, manage children's assigned tasks overview, and optionally sync to a WebDAV server.

## Screens

| Screen | Description |
|---|---|
| **Taken** | Personal task manager — quick-add, swipe-to-complete, priorities, categories, due dates with separate date/time controls, recurrence. Enabling a reminder defaults to one hour from now rounded up to the next half hour; the time dialog focuses hours. **Smart reminder chips** propose contextual times based on title and history. **Doorsturen** sends tasks to partner or individual kids with connection-aware gating. A **suggestion banner** on the Privé tab shows on-device self suggestions. |
| **Familie** | Conditionally visible when partner is paired or kids are connected. **Voorstellen** tab: structured sections for self suggestions, partner suggestions (generic templates + **Dit ziet je partner** preview), and incoming partner proposals. **Kinderen** tab: overview of tasks assigned to each enrolled child. |
| **Notities** | Markdown notes, personal or shared. List rows show a note icon, title, reminder, and “Gedeeld” — **not** the body. Editor uses the same bottom-sheet layout as tasks. |
| **Instellingen** | WebDAV config, connection test, **theme selector** (Licht, Zand, Schemer, Nacht). **Kluis**: verify or show the 12-word phrase (device lock). **Familie** section: Partner pairing (share/scan QR), Kids enrollment (QR without WebDAV password) with status. **Back-up & Herstel**: encrypted `.kvault` export/import (passphrase required; no key in the file). Restoring a backup automatically reschedules all notifications. |

## Family Setup

### Partner Pairing
1. Settings → Familie → Partner → "Familiesleutel delen via QR"
2. Write down the 12 family words (quiz), then show the QR (entropy only)
3. Partner scans **or** types the same 12 words and checks the fingerprint
4. Partnership activated; `family.key.enc` is stored in the personal WebDAV folder

### Kids Enrollment
Each child device enrolls independently:
1. Settings → Familie → Kinderen → "Kinderenapp koppelen"
2. Generate QR with family key + unique kid UUID (no WebDAV password)
3. Child device scans QR and types the WebDAV password once
4. Child receives tasks targeted to their UUID
5. Enrollment count shown in Settings

## Themes

Four Material 3 themes, chosen in **Instellingen**:

| Id | Label | Description |
|---|---|---|
| `light` | Licht | Helder blauw |
| `sand` | Zand | Warm papier |
| `dusk` | Schemer | Blauw-grijs donker |
| `night` | Nacht | OLED zwart |

Persisted name `dark` (pre-0.3) maps to `dusk`.

## WebDAV Setup & Encryption Keys

First launch is a **vault gate**: create a 12-word BIP-39 phrase (with a 3-word quiz) or restore from a `.kvault` file **or** from WebDAV with the same phrase.

When enabling WebDAV later, the app uses the already-unlocked vault key. It writes `/kinetic/{user}/vault.meta` if missing, or checks that the canary decrypts. A mismatch means that server already has a different vault.

The personal key is **derived from the 12 words**, not from the WebDAV password. Export is always `.kvault` (encrypted, no key, no WebDAV password).

## Data Model

### Tasks
- `xpReward` (integer, default 10): XP the child earns when completing a task sent via "Stuur naar kinderen". Configurable per task before sending.
- `targetKidId` (nullable): When set, task is encrypted as shared task with this UUID in `xKineticTargetKidId` iCal property. Kids sync orchestrator filters: only displays tasks where `xKineticTargetKidId == myKidId` or `xKineticTargetKidId` is null.

### Security
- **Personal vault**: 12 BIP-39 words → derived AES key; 16-byte entropy stored on-device for re-reveal behind the device lock
- **Family Key**: 12 BIP-39 words (quiz on create); QR v2 entropy; fingerprint; `family.key.enc` on personal WebDAV. A 0.2.x random family key is kept (no words).
- **Partner Paired Flag**: Stored as `kinetic_partner_paired` secure storage key; set only when QR pairing succeeds
- **Enrolled Kids List**: Stored as JSON in `kinetic_enrolled_kids` secure storage key; persisted on parent device only

## Development

```bash
cd apps/parent
flutter run        # run on device/emulator
flutter test       # run all tests
flutter build apk --release
```

All secrets are stored at runtime via secure storage — no `--dart-define` flags needed.

## Architecture

```
lib/
├── db/            — Drift schema (PersonalTasks with targetKidId column, PersonalNotes, PartnerProposals, AiSuggestions)
├── family/        — FamilyConnectionService (presence-based send gating)
├── notifications/ — local notification scheduling
├── partner/       — proposals, family screen, services
├── secure/        — secure storage wrappers
├── settings/      — WebDAV config, theme, family key share/scan screens
├── sync/          — SyncOrchestrator (WebDAV pull/push, LWW merge, xKineticTargetKidId embedding)
├── theme/         — Material 3 themes (Licht, Zand, Schemer, Nacht)
├── todo/          — task & note models, repositories, screens, reminder time helper, suggestion engine
├── vault/         — BIP-39 onboarding gate, restore (file / WebDAV), verify
└── main.dart      — root shell with conditional Familie nav item
```

## AI Suggestion Engine

A fully **offline, heuristic-based** engine that surfaces task suggestions in the **Taken** screen. No API calls or external models are used.

See also: [docs/SMART_FEATURES.md](docs/SMART_FEATURES.md) for reminder chips, send gating, and suggestion UI details.

### How it works

The engine runs on start and resume. A path is throttled for 24 hours **only after it created at least one suggestion**. Empty runs do not block later hits.

Partner-targeted detectors create suggestions — they do not auto-send proposals. Sending always goes through **Dit ziet je partner**.

| Detector | Trigger | Action |
|---|---|---|
| **Habit** | Same non-recurring task ≥ 2× overdue vs median interval, or one strong-keyword completion after ≥ 14 days | Suggests re-doing the task (→ you) |
| **Calendar** | Month prompt (belasting / schoolspullen / kerst) with no prior-year history required | Suggests a seasonal chore (→ you) |
| **Stale** | Open task > 7 days with no due date or reminder | Suggests setting a reminder on that task (→ you) |
| **Seasonal** | Completed in the same calendar month last year | Suggests re-doing it (→ you) |
| **Partner complement** | Keywords in **your** open tasks, including private | Generic partner hint — never copies the private title (→ partner) |
| **Load balance** | ≥ 3 open tasks in the same category (private counted) | Generic “help with this category?” hint (→ partner) |

Each suggestion stores an `explanation` field with a human-readable reason. Heuristic tables live in `lib/todo/services/suggestion_heuristics.dart`.

### Suggestion UI

- **Privé tab**: `SuggestionBanner` shows the first pending self suggestion
- **Voorstellen tab**: three sections — **Voor jou**, **Voor partner**, **Van partner** (inbox)
- Actions per card: **Toevoegen** / **Herinnering** (stale), **Naar partner** (when paired, with preview), **Sluiten**; long-press to snooze 7 days
- Proposals created from partner suggestions are marked `autoGenerated` with a "Via suggestie" badge

Suggestions are stored in the local `AiSuggestions` table and never synced to WebDAV.

## Smart Reminder Chips

`ReminderProposalEngine` proposes contextual reminder chips when the Herinnering row has no date set. Signals include habit time-of-day, habit interval, title keywords, category defaults, and time-of-day fallbacks. The best chip is marked with ✨; long-press shows why it was suggested.

## Connection-Aware Send

`FamilyConnectionService` evaluates partner/kid connectivity from WebDAV presence (7-day connected / 14-day offline thresholds). The send sheet lists each family member individually with status. The send button is disabled when nobody is connected.

### WebDAV layout

```
/kinetic/{username}/
├── tasks/{uid}.ics        — personal tasks (personal key)
└── notes/{uid}.ics        — personal notes (personal key)

/kinetic/shared/
├── notes/{uid}.ics        — shared notes (family key)
├── proposals/{id}.json    — partner proposals (family key)
├── load/{parentId}.json   — workload metrics (family key)
├── tasks/{uid}.ics        — tasks assigned to children (family key, with xKineticTargetKidId)
├── presence/{deviceId}.json — heartbeat presence (family key, written every sync)
└── disconnect/{deviceId}.json — disconnect tombstone (family key, written on leave/remove)
```

### Backup Format
- **`.kvault` (current)**: JSON wrapper `{version, format: kvault, ciphertext}`. Ciphertext is AES-256-GCM with the derived vault key. Inner payload has the encrypted database blob and theme — **not** the mnemonic, raw key, or WebDAV password. Import requires the 12 words.
- Legacy `.kbak2` (plaintext `personalKey` in JSON) is no longer written. First-run **Oude back-up (.kbak2)** still imports it, then asks for a new 12-word phrase (the old key cannot become a mnemonic).

### Presence & Heartbeat Protocol
Every sync cycle each device writes an encrypted **presence file** to `/kinetic/shared/presence/{deviceId}.json` (family key). The file contains `deviceId`, `deviceType` (`'parent'` or `'kid'`), `displayName`, and `lastSeen` (UTC ISO-8601).

- **Parent Settings screen** reads presence files for the connected partner and displays a relative last-seen timestamp ("zojuist", "X minuten geleden", etc.).
- **Kids Settings screen** reads presence files for each enrolled kid, showing last-seen per kid in the list.
- Entries older than **14 days** are shown as a stale warning with error styling.

### Disconnect Tombstone Protocol
When a device explicitly leaves the family, it writes an encrypted **tombstone** to `/kinetic/shared/disconnect/{deviceId}.json` (family key) containing `deviceId`, `deviceType`, and `disconnectedAt`.

- **Parent leaves** (`_leaveFamily`): writes parent tombstone + deletes own presence file.
- **Kid removed** (`_confirmRemoveKid`): parent writes a kid tombstone + deletes that kid's presence file.
- **Kids app**: on each sync, checks for its own tombstone; if found, invokes `onDisconnected` callback so the app can prompt the user.
- **Parent app**: on each sync, `_processDisconnects` reads all tombstones, invokes `onDisconnectsDetected`, then deletes the tombstone files it processed.

## Conditional UI

**Familie nav item** is only visible when:
- Partner is paired (Flag: `kinetic_partner_paired == true`) OR
- At least one child is enrolled (`enrolledKids.length > 0`)

**Voorstellen tab** in Familie screen:
- Visible only when `partnerPaired == true`
- Shows "Geen voorstellen" when no proposals exist

**Kinderen tab** in Familie screen:
- Visible only when `enrolledKidsCount > 0`
- Displays live overview pulled from `/kinetic/shared/tasks/` grouped by enrolled kid name
