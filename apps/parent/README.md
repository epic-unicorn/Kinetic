# Kinetic Link — Parent App

Parent-facing Flutter app. Manage personal tasks and notes locally, coordinate with your co-parent via task proposals, manage children's assigned tasks overview, and optionally sync to a WebDAV server.

## Screens

| Screen | Description |
|---|---|
| **Taken** | Personal task manager — quick-add, swipe-to-complete, priorities, categories, due dates with separate date/time controls, recurrence. "Stuur naar partner" and "Stuur naar kinderen" action buttons to delegate tasks. |
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
├── db/            — Drift schema (PersonalTasks with targetKidId column, PersonalNotes, PartnerProposals)
├── notifications/ — local notification scheduling
├── partner/       — proposals, family screen, services
├── secure/        — secure storage wrappers
├── settings/      — WebDAV config, theme, family key share/scan screens
├── sync/          — SyncOrchestrator (WebDAV pull/push, LWW merge, xKineticTargetKidId embedding)
├── theme/         — Material 3 color schemes
├── todo/          — task & note models, repositories, screens
└── main.dart      — root shell with conditional Familie nav item
```

### WebDAV layout

```
/kinetic/{username}/
├── tasks/{uid}.ics        — personal tasks (personal key)
└── notes/{uid}.ics        — personal notes (personal key)

/kinetic/shared/
├── notes/{uid}.ics        — shared notes (family key)
├── proposals/{id}.json    — partner proposals (family key)
├── load/{parentId}.json   — workload metrics (family key)
└── tasks/{uid}.ics        — tasks assigned to children (family key, with xKineticTargetKidId)
```

### Backup Format
- **`.kbak2`** (new): Unencrypted JSON wrapper containing `personalKey` (base64) + `database` (base64 of encrypted .kbak blob)
- Export/import as one combined file in Settings → Back-up & Herstel

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
