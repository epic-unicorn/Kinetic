import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

/// Lifecycle state of a [SupportTicket].
enum TicketStatus {
  /// Newly created; not yet seen by a parent.
  open,

  /// A parent has acknowledged the ticket and is working on a resolution.
  inProgress,

  /// The parent has provided a resolution and marked the ticket resolved.
  resolved,

  /// No further action required; archived.
  closed,
}

/// A help-request raised by a child (or parent) and addressed by a parent.
///
/// [crdtVersion] is incremented on every mutation so that [CouchSyncService]
/// can apply the same higher-version-wins merge strategy used for [FamilyPlan].
class SupportTicket extends Equatable {
  /// CouchDB document id, prefixed with `ticket:` for easy filtering.
  final String id;
  final String familyPlanId;

  /// [DeviceIdentity.deviceId] of the member who raised the ticket.
  final String requesterId;

  /// Optional link to the [Task] that prompted this help request.
  final String? taskId;

  final String title;
  final String? description;
  final TicketStatus status;

  /// [DeviceIdentity.deviceId] of the parent who resolved the ticket.
  final String? resolvedById;
  final String? resolution;

  final int crdtVersion;
  final DateTime createdAt;

  /// Updated on every mutation; used as LWW tiebreaker in CRDT merge.
  final DateTime updatedAt;

  const SupportTicket({
    required this.id,
    required this.familyPlanId,
    required this.requesterId,
    this.taskId,
    required this.title,
    this.description,
    this.status = TicketStatus.open,
    this.resolvedById,
    this.resolution,
    required this.crdtVersion,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SupportTicket.create({
    required String familyPlanId,
    required String requesterId,
    required String title,
    String? taskId,
    String? description,
  }) {
    final now = DateTime.now().toUtc();
    return SupportTicket(
      id: 'ticket:${const Uuid().v4()}',
      familyPlanId: familyPlanId,
      requesterId: requesterId,
      taskId: taskId,
      title: title,
      description: description,
      status: TicketStatus.open,
      crdtVersion: 1,
      createdAt: now,
      updatedAt: now,
    );
  }

  SupportTicket copyWith({
    TicketStatus? status,
    String? resolvedById,
    String? resolution,
    String? description,
  }) => SupportTicket(
    id: id,
    familyPlanId: familyPlanId,
    requesterId: requesterId,
    taskId: taskId,
    title: title,
    description: description ?? this.description,
    status: status ?? this.status,
    resolvedById: resolvedById ?? this.resolvedById,
    resolution: resolution ?? this.resolution,
    crdtVersion: crdtVersion + 1,
    createdAt: createdAt,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'familyPlanId': familyPlanId,
    'requesterId': requesterId,
    'taskId': taskId,
    'title': title,
    'description': description,
    'status': status.name,
    'resolvedById': resolvedById,
    'resolution': resolution,
    'crdtVersion': crdtVersion,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory SupportTicket.fromJson(Map<String, dynamic> json) => SupportTicket(
    id: (json['_id'] ?? json['id']) as String,
    familyPlanId: json['familyPlanId'] as String,
    requesterId: json['requesterId'] as String,
    taskId: json['taskId'] as String?,
    title: json['title'] as String,
    description: json['description'] as String?,
    status: TicketStatus.values.byName(json['status'] as String),
    resolvedById: json['resolvedById'] as String?,
    resolution: json['resolution'] as String?,
    crdtVersion: json['crdtVersion'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    updatedAt: DateTime.parse(json['updatedAt'] as String),
  );

  @override
  List<Object?> get props => [id, familyPlanId, status, crdtVersion, updatedAt];
}
