/// A task in the iCal wire format (VTODO component).
class ICalTask {
  final String uid;
  final String summary;
  final String? description;
  final ICalTaskStatus status;

  /// iCal PRIORITY 0 (undefined) – 9 (lowest).  Kinetic uses: 0=none, 1=high.
  final int priority;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? dueAt;
  final DateTime? remindAt;

  /// RFC 5545 RRULE value, e.g. `FREQ=WEEKLY`.  Null means no recurrence.
  final String? rrule;

  const ICalTask({
    required this.uid,
    required this.summary,
    this.description,
    this.status = ICalTaskStatus.needsAction,
    this.priority = 0,
    required this.createdAt,
    required this.updatedAt,
    this.dueAt,
    this.remindAt,
    this.rrule,
  });

  ICalTask copyWith({
    String? uid,
    String? summary,
    String? description,
    ICalTaskStatus? status,
    int? priority,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? dueAt,
    DateTime? remindAt,
    String? rrule,
  }) {
    return ICalTask(
      uid: uid ?? this.uid,
      summary: summary ?? this.summary,
      description: description ?? this.description,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      dueAt: dueAt ?? this.dueAt,
      remindAt: remindAt ?? this.remindAt,
      rrule: rrule ?? this.rrule,
    );
  }

  @override
  String toString() =>
      'ICalTask(uid: $uid, summary: $summary, status: $status)';
}

enum ICalTaskStatus {
  needsAction,
  inProcess,
  completed,
  cancelled;

  String toICalString() => switch (this) {
        ICalTaskStatus.needsAction => 'NEEDS-ACTION',
        ICalTaskStatus.inProcess => 'IN-PROCESS',
        ICalTaskStatus.completed => 'COMPLETED',
        ICalTaskStatus.cancelled => 'CANCELLED',
      };

  static ICalTaskStatus fromICalString(String s) => switch (s.toUpperCase()) {
        'IN-PROCESS' => ICalTaskStatus.inProcess,
        'COMPLETED' => ICalTaskStatus.completed,
        'CANCELLED' => ICalTaskStatus.cancelled,
        _ => ICalTaskStatus.needsAction,
      };
}
