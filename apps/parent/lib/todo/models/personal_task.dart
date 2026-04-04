import 'package:uuid/uuid.dart';

import 'enums.dart';

// ---------------------------------------------------------------------------
// PersonalList — equivalent to a Reminders list
// ---------------------------------------------------------------------------

class PersonalList {
  final String id;
  final String name;
  final int colorValue;
  final int iconCodePoint;
  final bool isPrivateDefault;
  final int position;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalList({
    required this.id,
    required this.name,
    required this.colorValue,
    required this.iconCodePoint,
    required this.isPrivateDefault,
    required this.position,
    required this.createdAt,
    required this.updatedAt,
  });

  static PersonalList create({
    required String name,
    int colorValue = 0xFF44BBA4,
    int iconCodePoint = 0xe156, // Icons.list
    bool isPrivateDefault = false,
    int position = 0,
  }) {
    final now = DateTime.now().toUtc();
    return PersonalList(
      id: const Uuid().v4(),
      name: name,
      colorValue: colorValue,
      iconCodePoint: iconCodePoint,
      isPrivateDefault: isPrivateDefault,
      position: position,
      createdAt: now,
      updatedAt: now,
    );
  }

  PersonalList copyWith({
    String? name,
    int? colorValue,
    int? iconCodePoint,
    bool? isPrivateDefault,
    int? position,
  }) {
    return PersonalList(
      id: id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isPrivateDefault: isPrivateDefault ?? this.isPrivateDefault,
      position: position ?? this.position,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }
}

// ---------------------------------------------------------------------------
// PersonalSubtask — checklist item inside a PersonalTask
// ---------------------------------------------------------------------------

class PersonalSubtask {
  final String id;
  final String taskId;
  final String title;
  final bool isCompleted;
  final int sortOrder;

  const PersonalSubtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    required this.sortOrder,
  });

  static PersonalSubtask create({
    required String taskId,
    required String title,
    int sortOrder = 0,
  }) {
    return PersonalSubtask(
      id: const Uuid().v4(),
      taskId: taskId,
      title: title,
      isCompleted: false,
      sortOrder: sortOrder,
    );
  }

  PersonalSubtask copyWith({String? title, bool? isCompleted, int? sortOrder}) {
    return PersonalSubtask(
      id: id,
      taskId: taskId,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

// ---------------------------------------------------------------------------
// PersonalTask — a parent's own todo item
// ---------------------------------------------------------------------------

class PersonalTask {
  final String id;
  final String? listId;
  final String title;
  final String? notes;
  final TaskPriority priority;
  final DateTime? dueDate;
  final bool isAllDay;
  final String? recurrenceRule;
  final bool isCompleted;
  final DateTime? completedAt;
  final bool isFlagged;

  /// When true, this task is never sent to partner as a proposal.
  final bool isPrivate;

  /// Set when this task has been converted to a kids mission.
  final String? kidsTaskId;

  final TaskCategory category;

  /// User-defined category label for grouping in the tasks list; null = uncategorized.
  final String? customCategory;

  /// When to fire a local reminder notification; null = no reminder.
  final DateTime? remindAt;

  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PersonalTask({
    required this.id,
    this.listId,
    required this.title,
    this.notes,
    required this.priority,
    this.dueDate,
    required this.isAllDay,
    this.recurrenceRule,
    required this.isCompleted,
    this.completedAt,
    required this.isFlagged,
    required this.isPrivate,
    this.kidsTaskId,
    required this.category,
    this.customCategory,
    this.remindAt,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  static PersonalTask create({
    required String title,
    String? listId,
    String? notes,
    TaskPriority priority = TaskPriority.none,
    DateTime? dueDate,
    bool isAllDay = true,
    String? recurrenceRule,
    bool isFlagged = false,
    bool isPrivate = false,
    TaskCategory? category,
    String? customCategory,
    DateTime? remindAt,
    int sortOrder = 0,
  }) {
    final now = DateTime.now().toUtc();
    return PersonalTask(
      id: const Uuid().v4(),
      listId: listId,
      title: title,
      notes: notes,
      priority: priority,
      dueDate: dueDate,
      isAllDay: isAllDay,
      recurrenceRule: recurrenceRule,
      isCompleted: false,
      completedAt: null,
      isFlagged: isFlagged,
      isPrivate: isPrivate,
      kidsTaskId: null,
      category: category ?? TaskCategory.other,
      customCategory: customCategory,
      remindAt: remindAt,
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
    );
  }

  PersonalTask copyWith({
    String? listId,
    String? title,
    String? notes,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? isAllDay,
    String? recurrenceRule,
    bool? isCompleted,
    DateTime? completedAt,
    bool? isFlagged,
    bool? isPrivate,
    String? kidsTaskId,
    TaskCategory? category,
    String? customCategory,
    bool clearCustomCategory = false,
    DateTime? remindAt,
    bool clearRemindAt = false,
    int? sortOrder,
  }) {
    return PersonalTask(
      id: id,
      listId: listId ?? this.listId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      isAllDay: isAllDay ?? this.isAllDay,
      recurrenceRule: recurrenceRule ?? this.recurrenceRule,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      isFlagged: isFlagged ?? this.isFlagged,
      isPrivate: isPrivate ?? this.isPrivate,
      kidsTaskId: kidsTaskId ?? this.kidsTaskId,
      category: category ?? this.category,
      customCategory: clearCustomCategory ? null : (customCategory ?? this.customCategory),
      remindAt: clearRemindAt ? null : (remindAt ?? this.remindAt),
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  /// True if the task is due today (or overdue) and not completed.
  bool get isDueToday {
    if (dueDate == null || isCompleted) return false;
    final today = DateTime.now();
    final d = dueDate!.toLocal();
    return d.year <= today.year && d.month <= today.month && d.day <= today.day;
  }
}
