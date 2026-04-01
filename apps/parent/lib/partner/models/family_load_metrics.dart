/// Family task load metrics — workload metrics per parent for load balancing.
class FamilyLoadMetrics {
  final String parentId;
  final String parentName;
  final int taskCount; // Total non-completed tasks
  final int urgentCount; // Tasks due within 7 days
  final Map<String, int> tasksByCategory; // {category: count}
  final DateTime calculatedAt;

  const FamilyLoadMetrics({
    required this.parentId,
    required this.parentName,
    required this.taskCount,
    required this.urgentCount,
    required this.tasksByCategory,
    required this.calculatedAt,
  });

  /// Create a snapshot with zero counts (no workload data available).
  static FamilyLoadMetrics empty(String parentId, String parentName) =>
      FamilyLoadMetrics(
        parentId: parentId,
        parentName: parentName,
        taskCount: 0,
        urgentCount: 0,
        tasksByCategory: const {},
        calculatedAt: DateTime.now().toUtc(),
      );

  @override
  String toString() =>
      'FamilyLoadMetrics(parentId: $parentId, tasks: $taskCount, urgent: $urgentCount, categories: $tasksByCategory)';
}
