# Kinetic Link — Parent App

Parent-facing Flutter app. Manage personal tasks and notes locally, coordinate with your co-parent via task proposals, manage children's assigned tasks overview, and optionally sync to a WebDAV server.

## Screens

| Screen | Description |
|---|---|
| **Taken** | Personal task manager — quick-add, swipe-to-complete, priorities, categories, due dates with separate date/time controls, recurrence. "Stuur naar partner" and "Stuur naar kinderen" action buttons to delegate tasks. A **suggestion banner** appears above the task list with AI-generated task suggestions (see [AI Suggestion Engine](#ai-suggestion-engine)). |
| **Familie** | Conditionally visible when partner is paired or kids are connected. **Voorstellen** tab: Incoming task proposals (accept/snooze/dismiss). **Kinderen** tab: Overview of tasks assigned to each enrolled child. |
| **Notities** | Markdown notes, personal or shared, synced to WebDAV when configured. Reminder uses separate date and time pickers; time defaults to current time + 1 hour rounded to the full hour. |
| **Instellingen** | WebDAV config, connection test, theme selector. **Familie** section: Partner pairing (share/scan QR), Kids enrollment (QR) with status. **Back-up & Herstel**: Combined backup/restore (personalKey + encrypted DB as single .kbak2 file). Restoring a backup automatically reschedules all notifications. |

## Family Setup

### Partner Pairing
1. Settings → Familie → Partner → "Familiesleutel delen via QR"
2. Partner scans QR on their device
3. Partnership activated; proposals sync automatically
4. "Partner gekoppeld" status shown in Settings

### Kids Enrollment
Each child device enrolls independently:
1. Settings → Familie → Kinderen → "Kinderenapp koppelen"
2. Generate QR with family key + unique kid UUID
3. Child device scans QR to enroll
4. Child receives tasks targeted to their UUID
5. Enrollment count shown in Settings

## WebDAV Setup & Encryption Keys

When enabling WebDAV sync for the first time (or switching to a different account), you are prompted to:
- **Import existing key** — paste your recovery JSON exported from the previous install to keep existing encrypted data readable.
- **Generate new key** — creates a new random personal key. Use this for a fresh install where no previous data exists on the WebDAV server.

You can export your recovery JSON at any time from the Back-up & Herstel section.

## Data Model

### Tasks
- `xpReward` (integer, default 10): XP the child earns when completing a task sent via "Stuur naar kinderen". Configurable per task before sending.
- `targetKidId` (nullable): When set, task is encrypted as shared task with this UUID in `xKineticTargetKidId` iCal property. Kids sync orchestrator filters: only displays tasks where `xKineticTargetKidId == myKidId` or `xKineticTargetKidId` is null.

### Security
- **Personal Key**: Encrypts personal tasks/notes; unique per parent device
- **Family Key**: Shared via QR; encrypts proposals, shared notes, kids tasks
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
├── notifications/ — local notification scheduling
├── partner/       — proposals, family screen, services
├── secure/        — secure storage wrappers
├── settings/      — WebDAV config, theme, family key share/scan screens
├── sync/          — SyncOrchestrator (WebDAV pull/push, LWW merge, xKineticTargetKidId embedding)
├── theme/         — Material 3 color schemes
├── todo/          — task & note models, repositories, screens, AI suggestion engine
└── main.dart      — root shell with conditional Familie nav item
```

## AI Suggestion Engine

A fully **offline, heuristic-based** engine that surfaces task suggestions in the **Taken** screen. No API calls or external models are used.

### How it works

The engine runs at most once per 24 hours (throttled via `AppSettings.lastSuggestionRunAt`). On each run it executes four detectors:

| Detector | Trigger | Action |
|---|---|---|
| **Habit** | You've completed the same non-recurring task ≥ 2 times and the median interval has been exceeded by ≥ 80% | Suggests re-doing the task (→ you) |
| **Partner complement** | You accepted a partner proposal whose title contains a keyword (e.g. "vakantie", "sport") | Sends the logical follow-up task to your partner automatically |
| **Seasonal** | A task was completed in the same calendar month in a prior year | Suggests re-doing it this year (→ you) |
| **Load balance** | You have ≥ 3 open non-private tasks in the same category | Proposes the oldest/most overdue one to your partner |

### Suggestion banner

The `SuggestionBanner` widget appears at the top of the open-tasks list when pending suggestions exist. Each card shows:
- Title and reason chip (habit / seizoen / partner / balans)
- **Toevoegen** — accepts the suggestion and creates a task in your list
- **→ Partner** (only when partner is paired) — sends it as a proposal instead
- **Sluiten** — dismisses the suggestion; long-press to snooze for 7 days

Suggestions are stored in the local `AiSuggestions` table and never synced to WebDAV.

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
- **`.kbak2` v2**: Unencrypted JSON wrapper containing `personalKey` (base64) + `database` (base64 of encrypted .kbak blob). No WebDAV configuration required to export.
- **`.kbak2` v3** (current): Extends v2 with a `settings` section containing `theme` (light/dark) and `webdav` (server URL, credentials, family key base64, enrolled kids, partner pairing state). Import is backwards compatible — v2 files restore only the database.
- Export never requires WebDAV to be configured: a personal key is generated silently on first export if one doesn't exist yet.
- Import restores all settings including theme, WebDAV credentials, family key, enrolled kids list, and partner pairing flag.

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
