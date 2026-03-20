import 'package:equatable/equatable.dart';

/// A single XP credit or debit event tied to a specific task or action.
class XpEvent extends Equatable {
  final String taskId;

  /// Positive = XP earned; negative = redemption or deduction.
  final int delta;
  final DateTime at;

  const XpEvent({required this.taskId, required this.delta, required this.at});

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'delta': delta,
    'at': at.toIso8601String(),
  };

  factory XpEvent.fromJson(Map<String, dynamic> json) => XpEvent(
    taskId: json['taskId'] as String,
    delta: json['delta'] as int,
    at: DateTime.parse(json['at'] as String),
  );

  @override
  List<Object?> get props => [taskId, delta, at];
}

/// CRDT-aware running XP balance for a single family member.
///
/// Document id format: `'xp:<memberId>'` — matches the CouchDB `_id` field.
/// [balance] always equals the sum of all [events] deltas.
class XpLedger extends Equatable {
  /// CouchDB document id: `'xp:<memberId>'`.
  final String id;
  final String memberId;

  /// Current XP balance — the sum of all [events] deltas.
  final int balance;

  /// Ordered history of all events that contributed to [balance].
  final List<XpEvent> events;

  final int crdtVersion;

  /// Updated on every mutation; acts as LWW tiebreaker when crdtVersions match.
  final DateTime updatedAt;

  const XpLedger({
    required this.id,
    required this.memberId,
    required this.balance,
    required this.events,
    required this.crdtVersion,
    required this.updatedAt,
  });

  /// Creates a zero-balance ledger for [memberId].
  factory XpLedger.empty(String memberId) => XpLedger(
    id: 'xp:$memberId',
    memberId: memberId,
    balance: 0,
    events: const [],
    crdtVersion: 1,
    updatedAt: DateTime.now().toUtc(),
  );

  /// Returns a new ledger with [event] applied to the balance and history.
  XpLedger applyEvent(XpEvent event) => XpLedger(
    id: id,
    memberId: memberId,
    balance: balance + event.delta,
    events: List.unmodifiable([...events, event]),
    crdtVersion: crdtVersion + 1,
    updatedAt: DateTime.now().toUtc(),
  );

  Map<String, dynamic> toJson() => {
    '_id': id,
    'memberId': memberId,
    'balance': balance,
    'events': events.map((e) => e.toJson()).toList(),
    'crdtVersion': crdtVersion,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory XpLedger.fromJson(Map<String, dynamic> json) {
    final eventsJson = json['events'] as List<dynamic>? ?? const [];
    return XpLedger(
      id: (json['_id'] ?? json['id']) as String,
      memberId: json['memberId'] as String,
      balance: json['balance'] as int,
      events: List.unmodifiable(
        eventsJson.map((e) => XpEvent.fromJson(e as Map<String, dynamic>)),
      ),
      crdtVersion: json['crdtVersion'] as int,
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  @override
  List<Object?> get props => [id, memberId, balance, crdtVersion, updatedAt];
}
