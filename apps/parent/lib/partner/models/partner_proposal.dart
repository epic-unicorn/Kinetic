import '../../../todo/models/enums.dart';

/// PartnerProposal — a task proposed by the other parent.
///
/// Proposals represent inter-parent communication: one parent suggests a task
/// for the other parent's household/queue. Status tracks acceptance workflow.
class PartnerProposal {
  final String id;
  final String fromParentId;
  final String taskTitle;
  final String? taskNotes;
  final TaskCategory taskCategory;
  final TaskPriority taskPriority;
  final DateTime? taskDueDate;
  final ProposalStatus status;
  final DateTime receivedAt;
  final DateTime updatedAt;

  const PartnerProposal({
    required this.id,
    required this.fromParentId,
    required this.taskTitle,
    this.taskNotes,
    required this.taskCategory,
    required this.taskPriority,
    this.taskDueDate,
    required this.status,
    required this.receivedAt,
    required this.updatedAt,
  });

  /// Change proposal status (e.g., pending → accepted).
  PartnerProposal copyWithStatus(ProposalStatus newStatus) {
    return PartnerProposal(
      id: id,
      fromParentId: fromParentId,
      taskTitle: taskTitle,
      taskNotes: taskNotes,
      taskCategory: taskCategory,
      taskPriority: taskPriority,
      taskDueDate: taskDueDate,
      status: newStatus,
      receivedAt: receivedAt,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  String toString() =>
      'PartnerProposal(id: $id, title: $taskTitle, status: $status, priority: $taskPriority)';
}
