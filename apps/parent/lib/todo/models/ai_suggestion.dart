import 'package:uuid/uuid.dart';

/// Reason a suggestion was generated.
enum SuggestionReason {
  habit,
  partnerComplement,
  seasonal,
  loadBalance,
  stale,
  calendar,
}

extension SuggestionReasonLabel on SuggestionReason {
  String get label => switch (this) {
    SuggestionReason.habit => 'Gewoonte',
    SuggestionReason.partnerComplement => 'Partner-aanvulling',
    SuggestionReason.seasonal => 'Seizoensgebonden',
    SuggestionReason.loadBalance => 'Taakverdeling',
    SuggestionReason.stale => 'Open taak',
    SuggestionReason.calendar => 'Kalender',
  };

  bool get isSelfTargeted =>
      this == SuggestionReason.habit ||
      this == SuggestionReason.seasonal ||
      this == SuggestionReason.stale ||
      this == SuggestionReason.calendar;

  bool get isPartnerTargeted =>
      this == SuggestionReason.partnerComplement ||
      this == SuggestionReason.loadBalance;
}

/// Lifecycle state of a suggestion.
enum SuggestionStatus { pending, accepted, dismissed, snoozed }

class AiSuggestion {
  final String id;
  final String title;
  final String? notes;
  final int priority;
  final String category;
  final DateTime? suggestedDueDate;
  final SuggestionReason reason;
  final SuggestionStatus status;
  final DateTime? snoozeUntil;
  final String? explanation;
  final DateTime createdAt;
  final DateTime updatedAt;

  const AiSuggestion({
    required this.id,
    required this.title,
    this.notes,
    required this.priority,
    required this.category,
    this.suggestedDueDate,
    required this.reason,
    required this.status,
    this.snoozeUntil,
    this.explanation,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPartnerTargeted => reason.isPartnerTargeted;

  static AiSuggestion create({
    required String title,
    String? notes,
    int priority = 0,
    String category = 'other',
    DateTime? suggestedDueDate,
    required SuggestionReason reason,
    String? explanation,
  }) {
    final now = DateTime.now().toUtc();
    return AiSuggestion(
      id: const Uuid().v4(),
      title: title,
      notes: notes,
      priority: priority,
      category: category,
      suggestedDueDate: suggestedDueDate,
      reason: reason,
      status: SuggestionStatus.pending,
      explanation: explanation,
      createdAt: now,
      updatedAt: now,
    );
  }

  AiSuggestion copyWith({
    SuggestionStatus? status,
    DateTime? snoozeUntil,
    DateTime? updatedAt,
  }) {
    return AiSuggestion(
      id: id,
      title: title,
      notes: notes,
      priority: priority,
      category: category,
      suggestedDueDate: suggestedDueDate,
      reason: reason,
      status: status ?? this.status,
      snoozeUntil: snoozeUntil ?? this.snoozeUntil,
      explanation: explanation,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
