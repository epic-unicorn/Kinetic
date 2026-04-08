/// Family task load metrics — workload metrics per parent for load balancing.
class FamilyLoadMetrics {
  final String parentId;
  final String parentName;
  final int taskCount; // Total non-completed tasks
  final int urgentCount; // Tasks due within 7 days
  final int openTasksCount; // Same as taskCount (tasks not completed)
  final int pastDueTasksCount; // Tasks with dueDate before now
  final int totalCategoriesCount; // Number of unique categories in use
  final int notesCount; // Number of personal notes
  final int
  childrenTasksSent; // Number of tasks sent to kids (kidsTaskId not null)
  final int childrenTasksCompleted; // Number of kids tasks that are completed
  final DateTime calculatedAt;

  const FamilyLoadMetrics({
    required this.parentId,
    required this.parentName,
    required this.taskCount,
    required this.urgentCount,
    required this.openTasksCount,
    required this.pastDueTasksCount,
    required this.totalCategoriesCount,
    required this.notesCount,
    required this.childrenTasksSent,
    required this.childrenTasksCompleted,
    required this.calculatedAt,
  });

  /// Create a snapshot with zero counts (no workload data available).
  static FamilyLoadMetrics empty(String parentId, String parentName) =>
      FamilyLoadMetrics(
        parentId: parentId,
        parentName: parentName,
        taskCount: 0,
        urgentCount: 0,
        openTasksCount: 0,
        pastDueTasksCount: 0,
        totalCategoriesCount: 0,
        notesCount: 0,
        childrenTasksSent: 0,
        childrenTasksCompleted: 0,
        calculatedAt: DateTime.now().toUtc(),
      );

  @override
  String toString() =>
      'FamilyLoadMetrics(parentId: $parentId, tasks: $taskCount, urgent: $urgentCount, open: $openTasksCount, pastDue: $pastDueTasksCount, categories: $totalCategoriesCount, notes: $notesCount, childrenSent: $childrenTasksSent, childrenCompleted: $childrenTasksCompleted)';
}
