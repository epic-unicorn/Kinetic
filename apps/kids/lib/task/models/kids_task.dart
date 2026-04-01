/// Task category — matches parent app TaskCategory
enum TaskCategory {
  household,
  school,
  health,
  shopping,
  entertainment,
  other,
}

/// Task priority — matches parent app TaskPriority
enum TaskPriority {
  low,
  normal,
  high,
  urgent,
}

/// KidsTask — a task assigned by a parent to this child
///
/// Mirrors PersonalTask from parent app but: read-only for most fields
/// (assigned by parent), editable only for completion status.
class KidsTask {
  final String id;
  final String parentId;
  final String title;
  final String? notes;
  final TaskCategory category;
  final TaskPriority priority;
  final DateTime? dueDate;
  final bool isCompleted;
  final DateTime? completedAt;
  final int xpReward;
  final String syncState;
  final String? webdavEtag;
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

  /// Factory: from Drift row
  factory KidsTask.fromRow(
    String id,
    String parentId,
    String title,
    String? notes,
    String categoryStr,
    int priorityInt,
    DateTime? dueDate,
    bool isCompleted,
    DateTime? completedAt,
    int xpReward,
    String syncState,
    String? webdavEtag,
    DateTime createdAt,
    DateTime updatedAt,
  ) {
    return KidsTask(
      id: id,
      parentId: parentId,
      title: title,
      notes: notes,
      category: TaskCategory.values.firstWhere(
        (e) => e.name == categoryStr,
        orElse: () => TaskCategory.other,
      ),
      priority: TaskPriority.values[priorityInt],
      dueDate: dueDate,
      isCompleted: isCompleted,
      completedAt: completedAt,
      xpReward: xpReward,
      syncState: syncState,
      webdavEtag: webdavEtag,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

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

  /// Immutable copy with optional field overrides
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

  /// Check if task is due today (or overdue) and not completed
  bool get isDueToday {
    if (dueDate == null || isCompleted) return false;
    final today = DateTime.now();
    final d = dueDate!.toLocal();
    return d.year <= today.year &&
        d.month <= today.month &&
        d.day <= today.day;
  }

  /// Check if task is overdue
  bool get isOverdue {
    if (dueDate == null || isCompleted) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  @override
  String toString() =>
      'KidsTask(id: $id, title: $title, category: $category, priority: $priority, completed: $isCompleted)';
}
