# Smart Features — Reminders, Family Send & AI Suggestions

This document describes the smart reminder chips, reminder time defaults, notes list privacy, connection-aware task delegation, and the on-device suggestion engine in the parent app.

## Notes list

Note rows use a folded-note icon (same visual weight as a task checkbox) plus title, reminder, and a “Gedeeld” badge. The markdown body is **not** previewed in the list.

## Reminder time picker

When a reminder is enabled on a **new** task (or “Tijd toevoegen” on an all-day reminder), the default instant is **one hour from now, rounded up to the next half hour**.

| Now | Default |
|---|---|
| 08:00 | 09:00 |
| 08:21 | 09:30 |
| 08:31 | 10:00 |
| 23:40 | 01:00 next day |

Exact `:00` after the +1 hour step stays on the hour. The time dialog is a 24-hour input that **selects the hour field** so you can type immediately (`showHourFirstTimePicker` in `lib/todo/widgets/hour_first_time_picker.dart`). Rounding lives in `lib/todo/reminder_time.dart`.

The same picker is used for note reminders.

## Smart reminder chips

When creating or editing a task, the **Herinnering** row shows contextual `ActionChip` suggestions instead of four static presets.

### Engine

`ReminderProposalEngine` (`lib/todo/services/reminder_proposal_engine.dart`) runs on-device when the task sheet opens and when the title changes (300ms debounce).

### Signals (ranked by score)

| Signal | Example chip | Trigger |
|--------|--------------|---------|
| Habit time | `Za 10:00` | ≥2 completions with same title; most common weekday + hour |
| Habit interval | `Over 2 dagen` | Median interval exceeded by ≥80% |
| Keyword | `Morgen 07:00` | Title contains `school`, `sport`, `boodschappen`, … |
| Category | `Za 09:00` | Default per `TaskCategory` when no history |
| Contextual | `Vanavond 20:00` | Time-of-day aware quick options |
| Fallback | `1 uur` | Backfill to always show 4 chips |

The first chip is highlighted with a ✨ icon. Long-press shows a tooltip with the explanation.

## Connection-aware send

`FamilyConnectionService` (`lib/family/family_connection_service.dart`) evaluates partner and kid connectivity from WebDAV presence data.

### Thresholds

| State | Condition | Send allowed? |
|-------|-----------|---------------|
| Connected | `lastSeen` ≤ 7 days | Yes |
| Stale | 7–14 days | Yes, with confirm warning |
| Offline | >14 days or no presence | No |

When WebDAV presence is unavailable (no sync configured), enrolled members are treated as connected-but-stale so local-only setups still work.

### Send sheet

The **Doorsturen** button is disabled when nobody is connected. The sheet lists:

- **Partner** — one row with connection status
- **Kinderen** — one row per enrolled kid with connection status

Offline members are visible but disabled. XP reward is still configured in the confirm dialog.

## AI suggestion engine

`AiSuggestionEngine` (`lib/todo/services/ai_suggestion_engine.dart`) runs on app start and resume. Detectors create `AiSuggestion` rows first — nothing is auto-sent to the partner.

### Throttle

Each path (self / partner) is throttled for 24 hours **only after that path created at least one suggestion**. An empty run does not set `lastSuggestionRunAt` / `lastPartnerSuggestionRunAt`, so new tasks can surface hints on the next open.

Partner detectors run when a partner is paired (`proposalRepo != null`). They do not require WebDAV `parentId` to *generate* hints; sending still needs pairing + parent id.

### Detectors

| Detector | Target | Trigger | Payload |
|----------|--------|---------|---------|
| **Habit** | Voor jou | Same non-recurring title completed ≥ 2× and days since last ≥ 80% of the median interval, **or** a single completion of a strong keyword (`boodschappen`, `wasgoed`, …) after ≥ 14 days | Original title |
| **Calendar** | Voor jou | Month-based prompt with no history (March belasting, August schoolspullen, December kerst) unless an open task already covers that theme | Fixed prompt title |
| **Stale** | Voor jou | Open task older than 7 days with no due date and no reminder | Same title; **Toevoegen / Herinnering** sets due date on the existing task |
| **Seasonal** | Voor jou | Completed in the same calendar month in a prior year | Original title |
| **Partner complement** | Voor partner | Keywords in **your** open tasks, including private (e.g. `school`, `huiswerk`, `dokter`) | **Generic template only** — never the source title or notes |
| **Load balance** | Voor partner | ≥ 3 open tasks in one category (private counted; `other` needs ≥ 5) | Generic “Kan jij deze week iets in [categorie] oppakken?” |

Keyword families and calendar prompts live in `lib/todo/services/suggestion_heuristics.dart`. Partner templates are capped at one per family per 14 days (`hasRecentWithTitle`).

Example: a private task “Afspraak GZA schoolarts 14:30” can produce “Schoolronde of opvang deze week?” — the partner never sees GZA or the time.

### UI

- **Privé tab**: `SuggestionBanner` shows the first pending self suggestion
- **Voorstellen tab**: three sections — **Voor jou**, **Voor partner**, **Van partner**
- **Naar partner** opens **Dit ziet je partner** (`confirmAndSendSuggestionToPartner`) before sending
- Partner-targeted proposals are marked `autoGenerated` with a “Via suggestie” badge
- Stale suggestions use **Herinnering** instead of creating a duplicate task

### Database

`AiSuggestions.explanation` stores the human-readable reason (schema v12). `reason` is a string enum: `habit`, `seasonal`, `calendar`, `stale`, `partnerComplement`, `loadBalance`.
