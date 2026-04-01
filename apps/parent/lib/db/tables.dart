// Drift table definitions for the parent app local database.
// Run `dart run build_runner build` to regenerate `app_database.g.dart`.

import 'package:drift/drift.dart';

// ---------------------------------------------------------------------------
// PersonalLists — user-created groups (like Reminders lists)
// ---------------------------------------------------------------------------

@DataClassName('PersonalListRow')
class PersonalLists extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get colorValue =>
      integer().withDefault(const Constant(0xFF44BBA4))();
  IntColumn get iconCodePoint =>
      integer().withDefault(const Constant(0xe156))(); // Icons.list
  BoolColumn get isPrivateDefault =>
      boolean().withDefault(const Constant(false))();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// PersonalTasks — parent's own todo items
// ---------------------------------------------------------------------------

@DataClassName('PersonalTaskRow')
class PersonalTasks extends Table {
  TextColumn get id => text()();

  // null = inbox (not in any list)
  TextColumn get listId => text().nullable().references(PersonalLists, #id)();

  TextColumn get title => text()();
  TextColumn get notes => text().nullable()();

  // 0 = none, 1 = low (!), 2 = medium (!!), 3 = high (!!!)
  IntColumn get priority => integer().withDefault(const Constant(0))();

  // Stored as UTC milliseconds since epoch; null = no due date
  DateTimeColumn get dueDate => dateTime().nullable()();
  BoolColumn get isAllDay => boolean().withDefault(const Constant(true))();

  // iCalendar RRULE string e.g. "FREQ=DAILY" — null = no recurrence
  TextColumn get recurrenceRule => text().nullable()();

  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();

  BoolColumn get isFlagged => boolean().withDefault(const Constant(false))();

  // true = never propose this task to partner
  BoolColumn get isPrivate => boolean().withDefault(const Constant(false))();

  // Set when this task was delegated to a child (kids task id)
  TextColumn get kidsTaskId => text().nullable()();

  // Auto-detected: household / health / admin / school / finance / other
  TextColumn get category => text().withDefault(const Constant('other'))();

  /// When to fire a local reminder notification; null = no reminder.
  DateTimeColumn get remindAt => dateTime().nullable()();

  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  // WebDAV sync metadata
  /// ETag returned by the server after the last successful PUT/GET.
  /// Null = never synced.
  TextColumn get webdavEtag => text().nullable()();

  /// 'clean' | 'dirty' | 'deleted'. 'dirty' = local change not yet pushed.
  TextColumn get syncState => text().withDefault(const Constant('dirty'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// PersonalNotes — parent's own notes (plaintext / markdown)
// ---------------------------------------------------------------------------

@DataClassName('PersonalNoteRow')
class PersonalNotes extends Table {
  TextColumn get id => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();

  /// true = encrypted with family key and stored in shared WebDAV folder.
  BoolColumn get isShared => boolean().withDefault(const Constant(false))();

  DateTimeColumn get remindAt => dateTime().nullable()();

  // WebDAV sync metadata
  TextColumn get webdavEtag => text().nullable()();
  TextColumn get syncState => text().withDefault(const Constant('dirty'))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// PersonalSubtasks — checklist items inside a PersonalTask
// ---------------------------------------------------------------------------

@DataClassName('PersonalSubtaskRow')
class PersonalSubtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().references(PersonalTasks, #id)();
  TextColumn get title => text()();
  BoolColumn get isCompleted => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// PartnerProposals — tasks proposed by the other parent (C3 inbox)
// ---------------------------------------------------------------------------

@DataClassName('PartnerProposalRow')
class PartnerProposals extends Table {
  TextColumn get id => text()();

  // Originating parent's member ID
  TextColumn get fromParentId => text()();

  // The synced task content
  TextColumn get taskTitle => text()();
  TextColumn get taskNotes => text().nullable()();
  TextColumn get taskCategory => text().withDefault(const Constant('other'))();
  IntColumn get taskPriority => integer().withDefault(const Constant(0))();
  DateTimeColumn get taskDueDate => dateTime().nullable()();

  // pending / accepted / snoozed / dismissed
  TextColumn get status => text().withDefault(const Constant('pending'))();

  // Sync state: clean (synced), dirty (modified locally), deleted (soft-delete)
  TextColumn get syncState => text().withDefault(const Constant('clean'))();

  DateTimeColumn get receivedAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
