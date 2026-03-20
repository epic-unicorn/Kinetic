import 'package:kinetic_core/kinetic_core.dart';

import '../models/xp_ledger.dart';
import '../store/document_store.dart';

/// Result returned by [ApprovalService.approveTask].
class ApprovalResult {
  final Task completedTask;
  final XpLedger updatedLedger;

  const ApprovalResult({
    required this.completedTask,
    required this.updatedLedger,
  });
}

/// Handles the task proof-submission workflow (approve / reject).
///
/// When a child submits a proof photo for a [TaskCategory.mission], the task
/// transitions to [TaskStatus.pendingApproval]. A parent then calls
/// [approveTask] or [rejectTask].
///
/// Both operations persist changes via [DocumentStore], which in production is
/// backed by [CouchSyncService] and synced to peers on the next heartbeat.
class ApprovalService {
  final DocumentStore _store;

  ApprovalService({required DocumentStore store}) : _store = store;

  // ---------------------------------------------------------------------------
  // Approve
  // ---------------------------------------------------------------------------

  /// Marks [task] as [TaskStatus.completed] and credits the assigned child's
  /// XP ledger with [Task.xpReward] points.
  ///
  /// Throws [ArgumentError] if [task.status] is not [TaskStatus.pendingApproval]
  /// or if [task.assignedToId] is null.
  ApprovalResult approveTask({required Task task, required String approverId}) {
    if (task.status != TaskStatus.pendingApproval) {
      throw ArgumentError(
        'Cannot approve task "${task.id}": '
        'status is ${task.status.name}, expected pendingApproval.',
      );
    }
    if (task.assignedToId == null) {
      throw ArgumentError(
        'Cannot approve task "${task.id}": assignedToId is null.',
      );
    }

    // Mark task completed and persist.
    final completedTask = task.copyWith(status: TaskStatus.completed);
    _store.upsert({'_id': completedTask.id, ...completedTask.toJson()});

    // Find or create the child's XP ledger.
    final ledgerId = 'xp:${task.assignedToId}';
    final existing = _store.all
        .where((d) => d['_id'] == ledgerId)
        .map((d) => XpLedger.fromJson(d))
        .firstOrNull;
    final ledger = existing ?? XpLedger.empty(task.assignedToId!);

    // Apply the XP event and persist.
    final updated = ledger.applyEvent(
      XpEvent(
        taskId: task.id,
        delta: task.xpReward,
        at: DateTime.now().toUtc(),
      ),
    );
    _store.upsert(updated.toJson());

    return ApprovalResult(completedTask: completedTask, updatedLedger: updated);
  }

  // ---------------------------------------------------------------------------
  // Reject
  // ---------------------------------------------------------------------------

  /// Returns the task to [TaskStatus.inProgress] so the child can try again.
  ///
  /// Optionally records [reason] as the task description.
  /// No XP is awarded. Throws [ArgumentError] if status is not
  /// [TaskStatus.pendingApproval].
  Task rejectTask({
    required Task task,
    required String approverId,
    String? reason,
  }) {
    if (task.status != TaskStatus.pendingApproval) {
      throw ArgumentError(
        'Cannot reject task "${task.id}": '
        'status is ${task.status.name}, expected pendingApproval.',
      );
    }

    final rejected = task.copyWith(
      status: TaskStatus.inProgress,
      description: reason,
    );
    _store.upsert({'_id': rejected.id, ...rejected.toJson()});
    return rejected;
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// All tasks currently awaiting parent approval.
  List<Task> get pendingTasks => _store.all
      .where((d) => d['status'] == TaskStatus.pendingApproval.name)
      .map((d) => Task.fromJson(d))
      .toList();

  /// XP ledger for [memberId], or an empty ledger if none exists yet.
  XpLedger ledgerFor(String memberId) {
    final ledgerId = 'xp:$memberId';
    final doc = _store.all.where((d) => d['_id'] == ledgerId).firstOrNull;
    return doc != null ? XpLedger.fromJson(doc) : XpLedger.empty(memberId);
  }
}
