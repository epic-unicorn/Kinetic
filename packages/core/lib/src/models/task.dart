import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Differentiates gamified Missions (earn XP) from non-XP Habits and adult tasks.
enum TaskCategory {
  /// Kids' chores / school work — earns XP and requires proof photo.
  mission,

  /// Routine habits (brushing teeth) — tracked but never earn XP.
  habit,

  /// Parent-assigned adult tasks (Book Dentist, Handle Dinner).
  parentTask,
}

enum TaskStatus {
  pending,
  inProgress,

  /// Mission photo submitted; awaiting parent approval before XP is granted.
  pendingApproval,
  completed,

  /// dueDate + 1 day has passed with no kid response.
  overdue,
}

/// A single unit of work (mission, habit, or parent task) in the Family Plan.
///
/// [updatedAt] is the CRDT tiebreaker for last-write-wins resolution in Phase 2.
class Task extends Equatable {
  final String id;
  final String familyPlanId;
  final String createdById;
  final String? assignedToId;
  final String title;
  final String? description;
  final TaskCategory category;
  final TaskStatus status;

  /// XP awarded on completion. Always 0 for [TaskCategory.habit] and
  /// [TaskCategory.parentTask].
  final int xpReward;

  /// Device-local path of the proof photo; non-null only after submission.
  final String? proofPhotoPath;

  /// Optional deadline set by the parent when the mission is created.
  final DateTime? dueDate;

  final DateTime createdAt;

  /// Updated on every state transition; used as LWW timestamp in CRDT merge.
  final DateTime updatedAt;

  const Task({
    required this.id,
    required this.familyPlanId,
    required this.createdById,
    this.assignedToId,
    required this.title,
    this.description,
    required this.category,
    this.status = TaskStatus.pending,
    required this.xpReward,
    this.proofPhotoPath,
    this.dueDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Task.create({
    required String familyPlanId,
    required String createdById,
    required String title,
    required TaskCategory category,
    int xpReward = 0,
    String? assignedToId,
    String? description,
    DateTime? dueDate,
  }) {
    final now = DateTime.now().toUtc();
    return Task(
      id: const Uuid().v4(),
      familyPlanId: familyPlanId,
      createdById: createdById,
      assignedToId: assignedToId,
      title: title,
      description: description,
      category: category,
      xpReward: xpReward,
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  Task copyWith({
    String? assignedToId,
    String? title,
    String? description,
    TaskCategory? category,
    TaskStatus? status,
    int? xpReward,
    String? proofPhotoPath,
    DateTime? dueDate,
  }) =>
      Task(
        id: id,
        familyPlanId: familyPlanId,
        createdById: createdById,
        assignedToId: assignedToId ?? this.assignedToId,
        title: title ?? this.title,
        description: description ?? this.description,
        category: category ?? this.category,
        status: status ?? this.status,
        xpReward: xpReward ?? this.xpReward,
        proofPhotoPath: proofPhotoPath ?? this.proofPhotoPath,
        dueDate: dueDate ?? this.dueDate,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'familyPlanId': familyPlanId,
        'createdById': createdById,
        'assignedToId': assignedToId,
        'title': title,
        'description': description,
        'category': category.name,
        'status': status.name,
        'xpReward': xpReward,
        'proofPhotoPath': proofPhotoPath,
        'dueDate': dueDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as String,
        familyPlanId: json['familyPlanId'] as String,
        createdById: json['createdById'] as String,
        assignedToId: json['assignedToId'] as String?,
        title: json['title'] as String,
        description: json['description'] as String?,
        category: TaskCategory.values.byName(json['category'] as String),
        status: TaskStatus.values.byName(json['status'] as String),
        xpReward: json['xpReward'] as int,
        proofPhotoPath: json['proofPhotoPath'] as String?,
        dueDate: json['dueDate'] != null
            ? DateTime.parse(json['dueDate'] as String)
            : null,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );

  @override
  List<Object?> get props =>
      [id, familyPlanId, title, status, xpReward, dueDate, updatedAt];
}
