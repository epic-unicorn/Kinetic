import '../../db/app_database.dart';
import '../models/family_load_metrics.dart';

/// LoadAnalyzer — calculates family task load metrics for proposal balancing.
class LoadAnalyzer {
  final AppDatabase _db;

  LoadAnalyzer({required AppDatabase db}) : _db = db;

  /// Calculate current task load metrics for the current user.
  /// [selfId] and [selfName] identify the current parent.
  Future<FamilyLoadMetrics> getMyLoad(String selfId, String selfName) async {
    final now = DateTime.now().toUtc();
    final tasks = await _db.select(_db.personalTasks).get();
    final notes = await _db.select(_db.personalNotes).get();

    // Count non-completed tasks
    final nonCompleted = tasks.where((t) => !t.isCompleted).toList();
    final taskCount = nonCompleted.length;

    // Count urgent tasks (due within 7 days)
    final urgentCount = nonCompleted.where((t) {
      if (t.dueDate == null) return false;
      final diff = t.dueDate!.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).length;

    // Count past due tasks (dueDate before now)
    final pastDueCount = nonCompleted.where((t) {
      if (t.dueDate == null) return false;
      return t.dueDate!.isBefore(now);
    }).length;

    // Count unique categories in use
    final categoriesInUse = <String>{};
    for (final task in tasks.where((t) => !t.isCompleted)) {
      categoriesInUse.add(task.category);
    }
    final totalCategoriesCount = categoriesInUse.length;

    // Count personal notes
    final notesCount = notes.length;

    // Count children tasks sent (where kidsTaskId is not null)
    final childrenTasksSent = tasks.where((t) => t.kidsTaskId != null).length;

    // Count children tasks that are completed (where kidsTaskId is not null and isCompleted)
    final childrenTasksCompleted = tasks.where((t) => t.kidsTaskId != null && t.isCompleted).length;

    return FamilyLoadMetrics(
      parentId: selfId,
      parentName: selfName,
      taskCount: taskCount,
      urgentCount: urgentCount,
      openTasksCount: taskCount,
      pastDueTasksCount: pastDueCount,
      totalCategoriesCount: totalCategoriesCount,
      notesCount: notesCount,
      childrenTasksSent: childrenTasksSent,
      childrenTasksCompleted: childrenTasksCompleted,
      calculatedAt: now,
    );
  }

  /// Check if the current parent's load is < 50% of a reference load.
  /// Returns true if good time to accept more proposals.
  Future<bool> hasCapacityForMoreProposals(int maxFamilyTaskCount) async {
    final tasks = await _db.select(_db.personalTasks).get();
    final selfTaskCount = tasks.where((t) => !t.isCompleted).length;
    return selfTaskCount < (maxFamilyTaskCount * 0.5);
  }
}
