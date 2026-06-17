import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../models/ai_suggestion.dart';

class AiSuggestionRepository {
  final AppDatabase _db;

  AiSuggestionRepository(this._db);

  // ---------------------------------------------------------------------------
  // Mapping helpers
  // ---------------------------------------------------------------------------

  AiSuggestion _rowToModel(AiSuggestionRow row) {
    return AiSuggestion(
      id: row.id,
      title: row.title,
      notes: row.notes,
      priority: row.priority,
      category: row.category,
      suggestedDueDate: row.suggestedDueDate,
      reason: SuggestionReason.values.firstWhere(
        (e) => e.name == row.reason,
        orElse: () => SuggestionReason.habit,
      ),
      status: SuggestionStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => SuggestionStatus.pending,
      ),
      snoozeUntil: row.snoozeUntil,
      explanation: row.explanation,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  AiSuggestionsCompanion _modelToCompanion(AiSuggestion s) {
    return AiSuggestionsCompanion.insert(
      id: s.id,
      title: s.title,
      notes: Value(s.notes),
      priority: Value(s.priority),
      category: Value(s.category),
      suggestedDueDate: Value(s.suggestedDueDate),
      reason: s.reason.name,
      status: Value(s.status.name),
      snoozeUntil: Value(s.snoozeUntil),
      explanation: Value(s.explanation),
      createdAt: s.createdAt,
      updatedAt: s.updatedAt,
    );
  }

  // ---------------------------------------------------------------------------
  // Queries
  // ---------------------------------------------------------------------------

  /// Watch suggestions that are pending and not snoozed (or snooze expired).
  Stream<List<AiSuggestion>> watchPending() {
    final now = DateTime.now().toUtc();
    return (_db.select(_db.aiSuggestions)
          ..where(
            (t) =>
                t.status.equals('pending') &
                (t.snoozeUntil.isNull() |
                    t.snoozeUntil.isSmallerThanValue(now)),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_rowToModel).toList());
  }

  /// Pending suggestions targeted at the user (habit / seasonal).
  Stream<List<AiSuggestion>> watchPendingSelf() {
    return watchPending().map(
      (all) => all
          .where(
            (s) =>
                s.reason == SuggestionReason.habit ||
                s.reason == SuggestionReason.seasonal,
          )
          .toList(),
    );
  }

  /// Pending suggestions the user may forward to their partner.
  Stream<List<AiSuggestion>> watchPendingPartner() {
    return watchPending().map(
      (all) => all
          .where(
            (s) =>
                s.reason == SuggestionReason.partnerComplement ||
                s.reason == SuggestionReason.loadBalance,
          )
          .toList(),
    );
  }

  /// Returns how many pending non-snoozed suggestions exist right now.
  Future<int> countPending() async {
    final now = DateTime.now().toUtc();
    final rows =
        await (_db.select(_db.aiSuggestions)..where(
              (t) =>
                  t.status.equals('pending') &
                  (t.snoozeUntil.isNull() |
                      t.snoozeUntil.isSmallerThanValue(now)),
            ))
            .get();
    return rows.length;
  }

  /// Watch pending suggestion count (drives the Voorstellen tab badge).
  Stream<int> watchPendingCount() => watchPending().map((list) => list.length);

  Future<int> countPendingSelf() async {
    final all = await watchPendingSelf().first;
    return all.length;
  }

  Future<int> countPendingPartner() async {
    final all = await watchPendingPartner().first;
    return all.length;
  }

  /// Returns true if a pending/snoozed suggestion with [title] already exists.
  Future<bool> hasPendingWithTitle(String title) async {
    final normalized = title.trim().toLowerCase();
    final rows =
        await (_db.select(_db.aiSuggestions)..where(
              (t) => t.status.equals('pending') | t.status.equals('snoozed'),
            ))
            .get();
    return rows.any((r) => r.title.trim().toLowerCase() == normalized);
  }

  // ---------------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------------

  /// Insert or ignore (deduplicate by title among pending/snoozed suggestions).
  Future<void> upsertSuggestion(AiSuggestion suggestion) async {
    if (await hasPendingWithTitle(suggestion.title)) return;
    await _db
        .into(_db.aiSuggestions)
        .insert(_modelToCompanion(suggestion), mode: InsertMode.insertOrIgnore);
  }

  Future<void> accept(String id) =>
      (_db.update(_db.aiSuggestions)..where((t) => t.id.equals(id))).write(
        AiSuggestionsCompanion(
          status: const Value('accepted'),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> dismiss(String id) =>
      (_db.update(_db.aiSuggestions)..where((t) => t.id.equals(id))).write(
        AiSuggestionsCompanion(
          status: const Value('dismissed'),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );

  Future<void> snooze(String id) =>
      (_db.update(_db.aiSuggestions)..where((t) => t.id.equals(id))).write(
        AiSuggestionsCompanion(
          status: const Value('snoozed'),
          snoozeUntil: Value(
            DateTime.now().toUtc().add(const Duration(days: 7)),
          ),
          updatedAt: Value(DateTime.now().toUtc()),
        ),
      );
}
