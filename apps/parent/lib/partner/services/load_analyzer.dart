import '../../todo/models/enums.dart';
import '../../todo/models/personal_task.dart';
import '../models/load_snapshot.dart';

// ---------------------------------------------------------------------------
// LoadAnalyzer — pure function.  No I/O, no state.
//
// Converts a flat list of PersonalTask objects into a LoadSnapshot by
// summing priority weights and applying urgency boosts.
// ---------------------------------------------------------------------------

class LoadAnalyzer {
  LoadAnalyzer._();

  static const Map<TaskPriority, double> _weight = {
    TaskPriority.high: 4.0,
    TaskPriority.medium: 2.0,
    TaskPriority.low: 1.0,
    TaskPriority.none: 0.5,
  };

  static LoadSnapshot analyze(List<PersonalTask> tasks) {
    final now = DateTime.now().toUtc();
    final endOfToday = DateTime.utc(now.year, now.month, now.day, 23, 59, 59);

    double total = 0;
    final perCat = <TaskCategory, double>{
      for (final c in TaskCategory.values) c: 0.0,
    };

    for (final task in tasks) {
      // Private tasks are never counted — they won't be proposed to a partner.
      if (task.isCompleted || task.isPrivate) continue;

      double score = _weight[task.priority] ?? 0.5;

      if (task.dueDate != null) {
        if (task.dueDate!.isBefore(now)) {
          score += 2.0; // overdue
        } else if (!task.dueDate!.isAfter(endOfToday)) {
          score += 1.0; // due today
        }
      }

      total += score;
      perCat[task.category] = (perCat[task.category] ?? 0) + score;
    }

    return LoadSnapshot(total: total, perCategory: perCat);
  }
}
