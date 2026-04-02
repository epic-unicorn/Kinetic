import 'package:drift/drift.dart';

import '../../notifications/notification_service.dart';

import '../../db/app_database.dart';
import '../models/enums.dart';
import '../models/personal_task.dart';
import 'category_classifier.dart';

// ---------------------------------------------------------------------------
// TodoRepository
//
// All read methods return Streams so the UI rebuilds automatically when
// the database changes.  Write methods are fire-and-forget futures.
// ---------------------------------------------------------------------------

class TodoRepository {
  final AppDatabase _db;
  final CategoryClassifier _classifier;
  final NotificationService? _notifications;
  final void Function()? onWrite;

  TodoRepository({
    required AppDatabase db,
    CategoryClassifier? classifier,
    NotificationService? notifications,
    this.onWrite,
  }) : _db = db,
       _classifier = classifier ?? categoryClassifier,
       _notifications = notifications;

  // ── Lists ──────────────────────────────────────────────────────────────────

  Stream<List<PersonalList>> watchLists() {
    return (_db.select(_db.personalLists)
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .watch()
        .map((rows) => rows.map(_listFromRow).toList());
  }

  Future<PersonalList> createList({
    required String name,
    int colorValue = 0xFF44BBA4,
    int iconCodePoint = 0xe156,
    bool isPrivateDefault = false,
  }) async {
    final list = PersonalList.create(
      name: name,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      isPrivateDefault: isPrivateDefault,
    );
    await _db.into(_db.personalLists).insert(_listToCompanion(list));
    return list;
  }

  Future<void> updateList(PersonalList list) async {
    await (_db.update(
      _db.personalLists,
    )..where((t) => t.id.equals(list.id))).write(_listToCompanion(list));
  }

  Future<void> deleteList(String listId) async {
    // Move tasks in this list to inbox before deleting.
    await (_db.update(_db.personalTasks)..where((t) => t.listId.equals(listId)))
        .write(const PersonalTasksCompanion(listId: Value(null)));
    await (_db.delete(
      _db.personalLists,
    )..where((t) => t.id.equals(listId))).go();
  }

  // ── Tasks ──────────────────────────────────────────────────────────────────

  /// All incomplete tasks, ordered by sort_order then created_at.
  Stream<List<PersonalTask>> watchAllTasks() {
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.isCompleted.equals(false) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// All incomplete tasks ordered by due date (nulls last), then created_at.
  Stream<List<PersonalTask>> watchOpenTasks() {
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.isCompleted.equals(false) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([
            // Sort rows with no due date after those that have one.
            (t) => OrderingTerm.asc(t.dueDate.isNull()),
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Tasks due today or overdue (incomplete only).
  Stream<List<PersonalTask>> watchTodayTasks() {
    final today = DateTime.now().toLocal();
    final endOfToday = DateTime(
      today.year,
      today.month,
      today.day,
      23,
      59,
      59,
    ).toUtc();
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.isCompleted.equals(false) &
                t.dueDate.isSmallerOrEqualValue(endOfToday) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.dueDate),
            (t) => OrderingTerm.asc(t.priority),
          ]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Tasks with a due date in the future (incomplete only).
  Stream<List<PersonalTask>> watchScheduledTasks() {
    final today = DateTime.now().toLocal();
    final startOfTomorrow = DateTime(
      today.year,
      today.month,
      today.day + 1,
    ).toUtc();
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.isCompleted.equals(false) &
                t.dueDate.isBiggerOrEqualValue(startOfTomorrow) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.dueDate)]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Flagged incomplete tasks.
  Stream<List<PersonalTask>> watchFlaggedTasks() {
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.isCompleted.equals(false) &
                t.isFlagged.equals(true) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Completed tasks (for showing completed section).
  Stream<List<PersonalTask>> watchCompletedTasks() {
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.isCompleted.equals(true) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  /// Permanently removes all completed tasks (bulk cleanup).
  Future<void> deleteCompletedTasks() async {
    // Soft-delete so the sync orchestrator can remove them from WebDAV.
    await (_db.update(_db.personalTasks)
          ..where((t) => t.isCompleted.equals(true)))
        .write(
      PersonalTasksCompanion(
        syncState: const Value('deleted'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    onWrite?.call();
  }

  /// Tasks belonging to a specific list.
  Stream<List<PersonalTask>> watchTasksInList(String listId) {
    return (_db.select(_db.personalTasks)
          ..where(
            (t) =>
                t.listId.equals(listId) &
                t.isCompleted.equals(false) &
                t.syncState.equals('deleted').not(),
          )
          ..orderBy([
            (t) => OrderingTerm.asc(t.sortOrder),
            (t) => OrderingTerm.asc(t.createdAt),
          ]))
        .watch()
        .map((rows) => rows.map(_taskFromRow).toList());
  }

  Future<PersonalTask> createTask({
    required String title,
    String? listId,
    String? notes,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    bool isAllDay = true,
    String? recurrenceRule,
    bool isFlagged = false,
    bool? isPrivate,
    TaskCategory? category,
    DateTime? remindAt,
  }) async {
    final autoCategory = category ?? _classifier.classify(title, notes: notes);

    // Inherit list privacy default when not explicitly set.
    bool taskIsPrivate = isPrivate ?? false;
    if (isPrivate == null && listId != null) {
      final row = await (_db.select(
        _db.personalLists,
      )..where((t) => t.id.equals(listId))).getSingleOrNull();
      if (row != null) taskIsPrivate = row.isPrivateDefault;
    }

    final task = PersonalTask.create(
      title: title,
      listId: listId,
      notes: notes,
      priority: priority,
      dueDate: dueDate,
      isAllDay: isAllDay,
      recurrenceRule: recurrenceRule,
      isFlagged: isFlagged,
      isPrivate: taskIsPrivate,
      category: autoCategory,
      remindAt: remindAt,
    );
    await _db.into(_db.personalTasks).insert(_taskToCompanion(task));
    await _scheduleReminderFor(task);
    onWrite?.call();
    return task;
  }

  Future<void> updateTask(PersonalTask task) async {
    await (_db.update(
      _db.personalTasks,
    )..where((t) => t.id.equals(task.id))).write(_taskToCompanion(task));
    // Cancel old reminder, then schedule the (possibly new) one.
    await _notifications?.cancelReminder(_notifId(task.id));
    await _scheduleReminderFor(task);
    onWrite?.call();
  }

  Future<void> completeTask(String taskId) async {
    await (_db.update(
      _db.personalTasks,
    )..where((t) => t.id.equals(taskId))).write(
      PersonalTasksCompanion(
        isCompleted: const Value(true),
        completedAt: Value(DateTime.now().toUtc()),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await _notifications?.cancelReminder(_notifId(taskId));
    onWrite?.call();
  }

  Future<void> uncompleteTask(String taskId) async {
    await (_db.update(
      _db.personalTasks,
    )..where((t) => t.id.equals(taskId))).write(
      PersonalTasksCompanion(
        isCompleted: const Value(false),
        completedAt: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    onWrite?.call();
  }

  Future<void> toggleFlag(String taskId, {required bool flagged}) async {
    await (_db.update(
      _db.personalTasks,
    )..where((t) => t.id.equals(taskId))).write(
      PersonalTasksCompanion(
        isFlagged: Value(flagged),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    onWrite?.call();
  }

  Future<void> togglePrivate(String taskId, {required bool isPrivate}) async {
    await (_db.update(
      _db.personalTasks,
    )..where((t) => t.id.equals(taskId))).write(
      PersonalTasksCompanion(
        isPrivate: Value(isPrivate),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    onWrite?.call();
  }

  Future<void> deleteTask(String taskId) async {
    await _notifications?.cancelReminder(_notifId(taskId));
    // Delete subtasks immediately (they are not tracked separately on WebDAV).
    await (_db.delete(
      _db.personalSubtasks,
    )..where((t) => t.taskId.equals(taskId))).go();
    // Soft-delete the task so the sync orchestrator can remove it from WebDAV.
    await (_db.update(
      _db.personalTasks,
    )..where((t) => t.id.equals(taskId))).write(
      PersonalTasksCompanion(
        syncState: const Value('deleted'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    onWrite?.call();
  }

  // ── Subtasks ───────────────────────────────────────────────────────────────

  Stream<List<PersonalSubtask>> watchSubtasks(String taskId) {
    return (_db.select(_db.personalSubtasks)
          ..where((t) => t.taskId.equals(taskId))
          ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
        .watch()
        .map((rows) => rows.map(_subtaskFromRow).toList());
  }

  Future<PersonalSubtask> addSubtask({
    required String taskId,
    required String title,
    int sortOrder = 0,
  }) async {
    final sub = PersonalSubtask.create(
      taskId: taskId,
      title: title,
      sortOrder: sortOrder,
    );
    await _db
        .into(_db.personalSubtasks)
        .insert(
          PersonalSubtasksCompanion.insert(
            id: sub.id,
            taskId: sub.taskId,
            title: sub.title,
            isCompleted: Value(sub.isCompleted),
            sortOrder: Value(sub.sortOrder),
          ),
        );
    return sub;
  }

  Future<void> toggleSubtask(
    String subtaskId, {
    required bool completed,
  }) async {
    await (_db.update(_db.personalSubtasks)
          ..where((t) => t.id.equals(subtaskId)))
        .write(PersonalSubtasksCompanion(isCompleted: Value(completed)));
  }

  Future<void> deleteSubtask(String subtaskId) async {
    await (_db.delete(
      _db.personalSubtasks,
    )..where((t) => t.id.equals(subtaskId))).go();
  }

  // ── Partner Proposals ──────────────────────────────────────────────────────

  Stream<List<PartnerProposal>> watchPendingProposals() {
    return (_db.select(_db.partnerProposals)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
        .watch()
        .map((rows) => rows.map(_proposalFromRow).toList());
  }

  Future<void> saveProposal(PartnerProposal proposal) async {
    await _db
        .into(_db.partnerProposals)
        .insertOnConflictUpdate(
          PartnerProposalsCompanion.insert(
            id: proposal.id,
            fromParentId: proposal.fromParentId,
            taskTitle: proposal.taskTitle,
            taskNotes: Value(proposal.taskNotes),
            taskCategory: Value(proposal.taskCategory.name),
            taskPriority: Value(proposal.taskPriority.index),
            taskDueDate: Value(proposal.taskDueDate),
            status: Value(proposal.status.name),
            receivedAt: proposal.receivedAt,
            updatedAt: proposal.updatedAt,
          ),
        );
  }

  Future<void> updateProposalStatus(
    String proposalId,
    ProposalStatus status,
  ) async {
    await (_db.update(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).write(
      PartnerProposalsCompanion(
        status: Value(status.name),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  // ── Load analysis support ──────────────────────────────────────────────────

  /// Returns all non-private, non-completed tasks eligible for proposal.
  Future<List<PersonalTask>> proposalCandidates() async {
    final now = DateTime.now().toUtc();
    final urgentCutoff = now.add(const Duration(hours: 24));
    final rows =
        await (_db.select(_db.personalTasks)..where(
              (t) =>
                  t.isCompleted.equals(false) &
                  t.isPrivate.equals(false) &
                  // Exclude tasks due within 24h — too urgent to reassign.
                  (t.dueDate.isNull() |
                      t.dueDate.isBiggerOrEqualValue(urgentCutoff)),
            ))
            .get();
    return rows.map(_taskFromRow).toList();
  }

  // ── Mapping helpers ────────────────────────────────────────────────────────

  PersonalList _listFromRow(PersonalListRow r) => PersonalList(
    id: r.id,
    name: r.name,
    colorValue: r.colorValue,
    iconCodePoint: r.iconCodePoint,
    isPrivateDefault: r.isPrivateDefault,
    position: r.position,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  PersonalListsCompanion _listToCompanion(PersonalList l) =>
      PersonalListsCompanion(
        id: Value(l.id),
        name: Value(l.name),
        colorValue: Value(l.colorValue),
        iconCodePoint: Value(l.iconCodePoint),
        isPrivateDefault: Value(l.isPrivateDefault),
        position: Value(l.position),
        createdAt: Value(l.createdAt),
        updatedAt: Value(l.updatedAt),
      );

  // ── Notification helpers ───────────────────────────────────────────────────

  int _notifId(String taskId) => taskId.hashCode.abs();

  Future<void> _scheduleReminderFor(PersonalTask task) async {
    final notif = _notifications;
    if (notif == null) return;
    // Fire a notification at the exact due date+time (only when not all-day).
    final dueDate = task.dueDate;
    if (dueDate == null || task.isAllDay) return;
    if (dueDate.isBefore(DateTime.now())) return;
    await notif.scheduleReminder(
      id: _notifId(task.id),
      title: task.title,
      body: 'Herinnering: ${task.title}',
      at: dueDate,
    );
  }

  PersonalTask _taskFromRow(PersonalTaskRow r) => PersonalTask(
    id: r.id,
    listId: r.listId,
    title: r.title,
    notes: r.notes,
    priority: TaskPriority.values[r.priority],
    dueDate: r.dueDate,
    isAllDay: r.isAllDay,
    recurrenceRule: r.recurrenceRule,
    isCompleted: r.isCompleted,
    completedAt: r.completedAt,
    isFlagged: r.isFlagged,
    isPrivate: r.isPrivate,
    kidsTaskId: r.kidsTaskId,
    category: TaskCategory.values.byName(r.category),
    remindAt: r.remindAt,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  PersonalTasksCompanion _taskToCompanion(PersonalTask t) =>
      PersonalTasksCompanion(
        id: Value(t.id),
        listId: Value(t.listId),
        title: Value(t.title),
        notes: Value(t.notes),
        priority: Value(t.priority.index),
        dueDate: Value(t.dueDate),
        isAllDay: Value(t.isAllDay),
        recurrenceRule: Value(t.recurrenceRule),
        isCompleted: Value(t.isCompleted),
        completedAt: Value(t.completedAt),
        isFlagged: Value(t.isFlagged),
        isPrivate: Value(t.isPrivate),
        kidsTaskId: Value(t.kidsTaskId),
        category: Value(t.category.name),
        remindAt: Value(t.remindAt),
        sortOrder: Value(t.sortOrder),
        createdAt: Value(t.createdAt),
        updatedAt: Value(t.updatedAt),
      );

  PersonalSubtask _subtaskFromRow(PersonalSubtaskRow r) => PersonalSubtask(
    id: r.id,
    taskId: r.taskId,
    title: r.title,
    isCompleted: r.isCompleted,
    sortOrder: r.sortOrder,
  );

  PartnerProposal _proposalFromRow(PartnerProposalRow r) => PartnerProposal(
    id: r.id,
    fromParentId: r.fromParentId,
    taskTitle: r.taskTitle,
    taskNotes: r.taskNotes,
    taskCategory: TaskCategory.values.byName(r.taskCategory),
    taskPriority: TaskPriority.values[r.taskPriority],
    taskDueDate: r.taskDueDate,
    status: ProposalStatus.values.byName(r.status),
    receivedAt: r.receivedAt,
    updatedAt: r.updatedAt,
  );
}
