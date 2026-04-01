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

    // Count non-completed tasks
    final nonCompleted = tasks.where((t) => !t.isCompleted).toList();
    final taskCount = nonCompleted.length;

    // Count urgent tasks (due within 7 days)
    final urgentCount = nonCompleted.where((t) {
      if (t.dueDate == null) return false;
      final diff = t.dueDate!.difference(now).inDays;
      return diff >= 0 && diff <= 7;
    }).length;

    // Count tasks by category
    final tasksByCategory = <String, int>{};
    for (final task in nonCompleted) {
      final cat = task.category;
      tasksByCategory[cat] = (tasksByCategory[cat] ?? 0) + 1;
    }

    return FamilyLoadMetrics(
      parentId: selfId,
      parentName: selfName,
      taskCount: taskCount,
      urgentCount: urgentCount,
      tasksByCategory: tasksByCategory,
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
