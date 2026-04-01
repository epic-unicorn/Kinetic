# Phase 13 Design — Kids Task Sync & XP System

## Overview

Phase 13 brings **kids app to parity with parent app**, enabling:
1. **Task sync from parent** — parents push/pull tasks via WebDAV
2. **Task completion** — kids mark tasks done, parents see updates
3. **XP reward system** — completed tasks earn points (early foundation)
4. **Approval workflow** — parents approve before marking task truly complete

This document outlines the architecture, data models, and sync strategy for Phase 13 Part 1 (Task Sync).

---

## Phase 13.1: Kids Task Sync

### Goals

- ✅ Parents can assign specific tasks to kids
- ✅ Kids device syncs assigned tasks via WebDAV (encrypted with family key)
- ✅ Kids can mark tasks complete (stored locally + synced)
- ✅ Parent sees kid's task completion status in real-time

### Non-goals (Phase 14+)

- XP calculation and display (tracked in DB, but UI not shown yet)
- Approval workflow (foundation laid, UI deferred)
- Activity/achievement badges
- Family leaderboard

---

## Architecture: Kids App v2

### Design Pattern

**Mirrored after parent app** — kids app follows same MVVM + repository pattern:

```
┌─────────────────┐
│   KidsHomeScreen│ (UI)
└────────┬────────┘
         │ watches stream
         ▼
┌─────────────────┐
│  KidsTaskRepo   │ (CRUD + streams)
└────────┬────────┘
         │ uses
         ▼
┌──────────────────────┐
│  AppDatabase (Drift) │ (SQLite)
└────────┬─────────────┘
         │ synced by
         ▼
┌──────────────────┐
│ SyncOrchestrator │ (WebDAV push/pull/merge)
└──────────────────┘
```

### How Task Assignment Works

```
Parent App                              Kids App
─────────────────────────────────────────────────

Parent navigates to Task               (parent creates/edits task)
Marks "Assign to {child}"              
        │
        ├─ Sets kidsAssignedTo = "{childId}"
        ├─ Sets syncState="dirty"
        └─ Waits for next sync
                    │
                    │ SyncOrchestrator._syncTasks()
                    │ (on parent's next sync trigger)
                    │
                    ├─ Finds tasks where kidsAssignedTo is set
                    ├─ Encrypts with family key (shared across all parents/kids)
                    └─ Pushes to WebDAV /kinetic/shared/tasks/assigned/
                                    │
                                    │ Next check (or manual sync)
                                    │
Kids App SyncOrchestrator._syncTasks()
(on kids' next sync trigger)
│
├─ Pulls from /kinetic/shared/tasks/assigned/
├─ Decrypts with family key (stored during enrollment)
├─ Merges with local DB (LWW on updatedAt)
└─ Updates UI in real-time via watchAll() stream
        │
        ▼
   Kids see task in list
   Kids can mark "Selesai" (Done)
   Status syncs back to parent via same WebDAV path
```

---

## Data Models

### KidsTask (Domain Model)

New model: `apps/kids/lib/task/models/kids_task.dart`

```dart
class KidsTask {
  final String id;                          // UUID
  final String parentId;                    // Which parent assigned this
  final String title;
  final String? notes;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;              // When kid marked it done
  final int xpReward;                       // XP points for completion (default 10)
  final String syncState;                   // 'clean', 'dirty', 'deleted'
  final String? webdavEtag;                 // For conflict detection
  final DateTime createdAt;
  final DateTime updatedAt;
  
  const KidsTask({
    required this.id,
    required this.parentId,
    required this.title,
    this.notes,
    required this.category,
    required this.priority,
    this.dueDate,
    this.isCompleted = false,
    this.completedAt,
    this.xpReward = 10,
    required this.syncState,
    this.webdavEtag,
    required this.createdAt,
    required this.updatedAt,
  });
  
  /// Mark task as complete
  KidsTask markComplete() => copyWith(
    isCompleted: true,
    completedAt: DateTime.now().toUtc(),
    syncState: 'dirty',
    updatedAt: DateTime.now().toUtc(),
  );
  
  /// Undo completion
  KidsTask markIncomplete() => copyWith(
    isCompleted: false,
    completedAt: null,
    syncState: 'dirty',
    updatedAt: DateTime.now().toUtc(),
  );
  
  KidsTask copyWith({
    String? id,
    String? parentId,
    String? title,
    String? notes,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool? isCompleted,
    DateTime? completedAt,
    int? xpReward,
    String? syncState,
    String? webdavEtag,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return KidsTask(
      id: id ?? this.id,
      parentId: parentId ?? this.parentId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: dueDate ?? this.dueDate,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      xpReward: xpReward ?? this.xpReward,
      syncState: syncState ?? this.syncState,
      webdavEtag: webdavEtag ?? this.webdavEtag,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
```

### Drift Database Schema

New table: `apps/kids/lib/db/tables.dart` (create new file, follows parent app pattern)

```dart
@DataClassName('KidsTaskRow')
class KidsTasks extends Table {
  TextColumn get id => text()();
  
  // Parent who assigned this task
  TextColumn get parentId => text()();
  
  // Task content
  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('other'))();
  IntColumn get priority => integer().withDefault(const Constant(0))();
  DateTimeColumn get dueDate => dateTime().nullable()();
  
  // Completion tracking
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  
  // XP (foundation for Phase 13.3)
  IntColumn get xpReward => integer().withDefault(const Constant(10))();
  
  // Sync
  TextColumn get syncState => text().withDefault(const Constant('clean'))();
  TextColumn get webdavEtag => text().nullable()();
  
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  
  @override
  Set<Column> get primaryKey => {id};
}
```

---

## Database Setup (AppDatabase)

### New Kids AppDatabase

File: `apps/kids/lib/db/app_database.dart` (mirrors parent app structure)

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [KidsTasks])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return driftDatabase(name: 'kids_app');
  }
}
```

### Generate Drift Code

```bash
cd apps/kids
flutter pub get
dart run build_runner build
```

This generates:
- `app_database.g.dart` with `_$AppDatabase` mixin
- Type-safe queries and update companions

---

## Services Layer

### 1. KidsTaskRepository (CRUD + Streams)

File: `apps/kids/lib/task/services/kids_task_repository.dart`

**API:**
```dart
class KidsTaskRepository {
  /// All assigned tasks, ordered by due date
  Stream<List<KidsTask>> watchAll();
  
  /// Only incomplete tasks
  Stream<List<KidsTask>> watchPending();
  
  /// Single task by id
  Stream<KidsTask?> watchOne(String id);
  
  /// Locally mark task complete (sets syncState='dirty')
  Future<void> markComplete(String taskId);
  
  /// Undo completion
  Future<void> markIncomplete(String taskId);
  
  /// Soft-delete (for parent deletions through sync)
  Future<void> delete(String taskId);
}
```

### 2. KidsSyncOrchestrator (WebDAV Sync)

File: `apps/kids/lib/sync/sync_orchestrator.dart`

**Inherits from SyncConfig** — kids app uses same encryption keys as parent app (stored during enrollment).

**API:**
```dart
class KidsSyncOrchestrator {
  final AppDatabase _db;
  final SyncConfig _config;
  
  /// Main sync loop — pull assigned tasks from /kinetic/shared/tasks/assigned/
  Future<void> sync() async {
    final client = WebDavClient(
      baseUrl: _config.baseUrl,
      username: _config.username,
      password: _config.password,
    );
    final service = WebDavSyncService(client: client, config: _config);
    try {
      await _syncTasks(service);
    } finally {
      client.dispose();
    }
  }
  
  /// Push local changes (completion status) back to WebDAV
  Future<void> _pushLocalChanges(WebDavSyncService service) async {
    // Find all dirty rows
    final dirtyRows = await (_db.select(_db.kidsTasks)
          ..where((t) => t.syncState.equals('dirty')))
        .get();
    
    // Push each as iCal VTODO
    for (final row in dirtyRows) {
      final icalTask = _rowToICalTask(row);
      await service.pushTask(icalTask); // encrypted with family key
      // Mark clean after successful push
      await (_db.update(_db.kidsTasks)..where((t) => t.id.equals(row.id)))
          .write(KidsTasksCompanion(
            syncState: const Value('clean'),
            webdavEtag: Value(icalTask.etag),
          ));
    }
  }
  
  /// Pull assigned tasks from parent via WebDAV
  Future<void> _pullRemoteTasks(WebDavSyncService service) async {
    // Pull from /kinetic/shared/tasks/assigned/
    final iCalTasks = await service.pullTasks(folder: 'shared/assigned');
    
    // Merge with local DB (LWW on updatedAt)
    for (final iCalTask in iCalTasks) {
      final remoteTask = _iCalToKidsTask(iCalTask);
      final existing = await (_db.select(_db.kidsTasks)
            ..where((t) => t.id.equals(remoteTask.id)))
          .getSingleOrNull();
      
      if (existing == null) {
        // New task from parent
        await _db.into(_db.kidsTasks).insert(_taskToCompanion(remoteTask));
      } else if (remoteTask.updatedAt.isAfter(existing.updatedAt)) {
        // Remote is newer — update locally
        await (_db.update(_db.kidsTasks)
              ..where((t) => t.id.equals(remoteTask.id)))
            .write(_taskToCompanion(remoteTask));
      }
      // else: local is newer, keep it (dirty), will push on next sync cycle
    }
  }
}
```

---

## Sync Flow: Detailed

### Scenario 1: Parent Assigns Task to Kid

```
1. Parent opens TasksScreen
2. Parent selects task → "Assign to Child"
3. DropdownButton shows available children
4. Parent confirms → task.kidsAssignedTo = "child_uuid"
5. Task marked dirty, saved to local DB
6. Parent navigates away

7. Next sync trigger (manual or auto):
   SyncOrchestrator._syncTasks() in parent app
   ├─ Finds: kidsAssignedTo != null && syncState="dirty"
   ├─ Serializes to VTODO in iCal format
   ├─ Encrypts with family key (PBKDF2 from WebDAV password)
   └─ Pushes to: /kinetic/shared/tasks/assigned/{taskId}.ics

8. Kid device (if connected):
   KidsSyncOrchestrator.sync() runs (on foreground resume or manual)
   ├─ Pulls from /kinetic/shared/tasks/assigned/
   ├─ Decrypts each with family key (kid has same password from enrollment)
   ├─ Parses iCal VTODO → KidsTask domain model
   ├─ Checks local DB for conflicts (LWW merge)
   └─ If new or remote is newer, insert/update in KidsTasks table

9. KidsHomeScreen watches stream:
   repository.watchPending() updates → new task appears in list
   Kid sees: "Opruimen" (Cleaning) — Due Today — Medium priority
```

### Scenario 2: Kid Marks Task Complete

```
1. Kid opens KidsHomeScreen
2. Kid taps "Opruimen" task
3. KidsTaskScreen shows:
   - Title, due date, priority, notes
   - "Selesai?" (Done?) button
4. Kid taps "Selesai"

5. Repository.markComplete(taskId):
   ├─ Sets isCompleted=true
   ├─ Sets completedAt=now
   ├─ Sets syncState="dirty"
   └─ Updates updatedAt=now

6. UI updates immediately (via stream)
   Task shows checkmark, potentially grayed out

7. Next sync trigger:
   KidsSyncOrchestrator._pushLocalChanges(service)
   ├─ Finds: syncState="dirty"
   ├─ Serializes updated task to VTODO
   ├─ Encrypts with family key
   └─ Pushes to: /kinetic/shared/tasks/assigned/{taskId}.ics

8. Parent device (if connected):
   SyncOrchestrator._syncTasks() in parent app
   ├─ Pulls from /kinetic/shared/tasks/assigned/
   ├─ Sees isCompleted=true, updatedAt=(kid's timestamp)
   ├─ Merges with local (LWW — kid's timestamp is newer)
   └─ Updates local DB: personal_tasks.isCompleted=true

9. Parent sees:
   TasksScreen task now shows completion checkmark
   Status badge shows "Selesai oleh {child}" (Completed by {child})
   In real-time or next refresh
```

---

## UI: Kids Home Screen

### Current Placeholder

```dart
class KidsHomeScreen extends StatelessWidget {
  const KidsHomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mijn Opdrachten')),
      body: const Center(child: Text('Alles klaar!')),
    );
  }
}
```

### After Phase 13.1 Implementation

```dart
class KidsHomeScreen extends StatefulWidget {
  final KidsTaskRepository repository;
  
  const KidsHomeScreen({super.key, required this.repository});
  
  @override
  State<KidsHomeScreen> createState() => _KidsHomeScreenState();
}

class _KidsHomeScreenState extends State<KidsHomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Opdrachten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _sync,
            tooltip: 'Synchroniseren',
          ),
        ],
      ),
      body: StreamBuilder<List<KidsTask>>(
        stream: widget.repository.watchAll(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final tasks = snapshot.data!;
          
          if (tasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text('Alles klaar!', style: TextStyle(fontSize: 18)),
                ],
              ),
            );
          }
          
          return ListView.builder(
            itemCount: tasks.length,
            padding: const EdgeInsets.all(8),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return _buildTaskCard(context, task);
            },
          );
        },
      ),
    );
  }
  
  Widget _buildTaskCard(BuildContext context, KidsTask task) {
    return Card(
      child: ListTile(
        leading: Checkbox(
          value: task.isCompleted,
          onChanged: (_) => _toggleTask(task.id, task.isCompleted),
        ),
        title: Text(task.title),
        subtitle: Text(task.category.name),
        trailing: task.dueDate != null
            ? Chip(label: Text(_formatDate(task.dueDate!)))
            : null,
      ),
    );
  }
  
  Future<void> _toggleTask(String taskId, bool isCompleted) async {
    if (isCompleted) {
      await widget.repository.markIncomplete(taskId);
    } else {
      await widget.repository.markComplete(taskId);
    }
  }
  
  Future<void> _sync() async {
    // Call KidsSyncOrchestrator.sync()
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Synchroniseren...')),
    );
  }
  
  String _formatDate(DateTime date) {
    final today = DateTime.now();
    final diff = date.difference(today).inDays;
    if (diff == 0) return 'Vandaag';
    if (diff == 1) return 'Morgen';
    return '${date.day}/${date.month}';
  }
}
```

---

## File Structure: Kids App After Phase 13.1

```
apps/kids/lib/
├── main.dart
│   └── KineticKidsApp
│   └── KidsHomeScreen (updated to use repository)
│
├── db/
│   ├── app_database.dart (new)
│   ├── app_database.g.dart (generated by Drift)
│   └── tables.dart (new)
│
├── task/
│   ├── models/
│   │   └── kids_task.dart (new)
│   ├── services/
│   │   └── kids_task_repository.dart (new)
│   └── screens/
│       └── kids_task_screen.dart (new, for task detail/completion)
│
├── sync/
│   └── sync_orchestrator.dart (new)
│
├── theme/
│   └── app_themes.dart (imported from parent app or shared)
│
└── secure/
    └── flutter_secure_key_value_store.dart (existing placeholder)
```

---

## Implementation Order

### Phase 13.1a: Foundation (Database + Models)

1. `apps/kids/lib/db/tables.dart` — Drift table definition
2. `apps/kids/lib/db/app_database.dart` — AppDatabase + migrations
3. `apps/kids/lib/task/models/kids_task.dart` — Domain model
4. Run `dart run build_runner build`

### Phase 13.1b: Services (Repository + Sync)

5. `apps/kids/lib/task/services/kids_task_repository.dart` — CRUD + streams
6. `apps/kids/lib/sync/sync_orchestrator.dart` — WebDAV push/pull/merge

### Phase 13.1c: UI & Integration

7. Update `main.dart` — inject repository, wire sync triggers
8. Update `KidsHomeScreen` — replace placeholder with StreamBuilder
9. Create `apps/kids/lib/task/screens/kids_task_screen.dart` — task detail/completion

### Phase 13.1d: Testing

10. Unit tests for `KidsTaskRepository`
11. Unit tests for `KidsSyncOrchestrator` (merge logic, iCal parsing)
12. Widget tests for `KidsHomeScreen`

---

## Enrollment & Configuration

### How Kids Device Gets WebDAV Credentials

**During parent enrollment** (Phase 12 — already done in v1, re-check for v2):

1. Parent scans hub QR or manually enters WebDAV details in Settings
2. SyncConfig stored securely in parent app
3. Parent opens Settings → "Add Child Device"
4. Shows QR code containing: `{baseUrl, username, password, familyKey}`
5. Child device scans → stores in secure storage
6. On next sync, child app pulls assigned tasks from WebDAV

For Phase 13.1, assume **kids device already has WebDAV config** (inherited from parent enrollment or manual setup). Later phases can add enrollment flow if needed.

---

## Testing Strategy

### Unit Tests

**KidsTaskRepository:**
- `watchAll()` returns stream of tasks
- `markComplete()` sets isCompleted + syncState
- Soft-delete works correctly

**KidsSyncOrchestrator:**
- `_pullRemoteTasks()` merges with LWW logic
- `_pushLocalChanges()` serializes dirty tasks
- Conflict resolution (remote wins if newer)

### Widget Tests

**KidsHomeScreen:**
- Empty state shows "Alles klaar!"
- Task list displays when data available
- Checkbox toggle calls `repository.markComplete()`
- Sync button triggers sync

### Integration Tests

- End-to-end: parent assigns task → kid device pulls → kid marks done → parent sees it
- (Deferred — depends on parent/kids communication setup)

---

## Security Considerations

✅ **Already handled by kinetic_webdav:**
- Family key derived from WebDAV password (PBKDF2)
- All tasks encrypted with family key before storage on WebDAV
- Kids device has same family key (from enrollment) → can decrypt

✅ **Kids sync only pulls assigned tasks:**
- Parent sets `kidsAssignedTo={childId}` → only that child's device pulls
- (Later: enforce authorization on WebDAV server side)

⚠️ **Future:** 
- Restrict kids device from reading other children's tasks
- Implement per-child encryption key (Phase 14?)

---

## Success Criteria

By end of Phase 13.1:

- [ ] Kids device can pull tasks assigned by parent via WebDAV
- [ ] Kids can mark tasks complete locally
- [ ] Completion status syncs back to parent
- [ ] Both apps show real-time updates via streams
- [ ] 20+ unit tests covering repository + sync
- [ ] 0 compilation errors, all tests passing
- [ ] Documentation updated (README, development.md)

---

## Notes for Implementation

1. **Reuse parent app patterns** — don't reinvent; copy/adapt:
   - `TodoRepository` → `KidsTaskRepository` (same interface style)
   - `SyncOrchestrator` from parent → adapt for kids (only pull assigned)
   - `main.dart` injection pattern → same for kids

2. **Defer XP UI** — Phase 13.1 stores `xpReward` in DB, but don't show XP badge/counter yet
   - Foundation laid for Phase 13.3

3. **Enrollment deferred** — assume kids device already has WebDAV config
   - Simplifies Phase 13.1 scope
   - Parent app > Settings > "Add Child Device" QR → future phase

4. **No kids list management** — parents manage children/assignments from parent app only
   - Kids app is read-only for tasks (except completion toggle)
   - Future: kids request tasks, parents approve assignments

5. **WebDAV folder structure:**
   - Parent app: `/kinetic/shared/tasks/` (all shared family tasks)
   - Kids sync: pulls from `/kinetic/shared/tasks/assigned/` (parent-assigned only)
   - Could be same folder with filtering on kidsAssignedTo field, or separate path for clarity

---

## Next Steps

1. ✅ **Design approved** — this document
2. → **Phase 13.1 Implementation** — follow file order above
3. → **Phase 13.2** — (Approval workflow setup)
4. → **Phase 13.3** — XP display in UI
5. → **Phase 14+** — additional kids features (leaderboard, achievements, etc.)
