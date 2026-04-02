import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../todo/models/enums.dart';
import '../models/partner_proposal.dart';

/// PartnerProposalRepository — CRUD for inter-parent task proposals.
///
/// Manages proposals from the other parent, supporting accept/snooze/dismiss workflow.
class PartnerProposalRepository {
  final AppDatabase _db;
  final _uuid = const Uuid();

  PartnerProposalRepository({required AppDatabase db}) : _db = db;

  /// All pending proposals, ordered by received date (newest first).
  Stream<List<PartnerProposal>> watchPending() {
    return (_db.select(_db.partnerProposals)
          ..where((t) => t.status.equals('pending'))
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
        .watch()
        .map((rows) => rows.map(_proposalFromRow).toList());
  }

  /// All proposals (any status), ordered by received date (newest first).
  Stream<List<PartnerProposal>> watchAll() {
    return (_db.select(_db.partnerProposals)
          ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
        .watch()
        .map((rows) => rows.map(_proposalFromRow).toList());
  }

  /// Stream a single proposal by id.
  Stream<PartnerProposal?> watchOne(String id) {
    return (_db.select(_db.partnerProposals)..where((t) => t.id.equals(id)))
        .watchSingleOrNull()
        .map((row) => row != null ? _proposalFromRow(row) : null);
  }

  /// Accept a proposal (creates task in parent's list and updates proposal status).
  Future<void> accept(String proposalId) async {
    await (_db.update(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).write(
      PartnerProposalsCompanion(
        status: const Value('accepted'),
        syncState: const Value('dirty'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Snooze a proposal (change status to snoozed, will resurface later).
  Future<void> snooze(String proposalId) async {
    await (_db.update(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).write(
      PartnerProposalsCompanion(
        status: const Value('snoozed'),
        syncState: const Value('dirty'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Dismiss a proposal (change status to dismissed, no action).
  Future<void> dismiss(String proposalId) async {
    await (_db.update(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).write(
      PartnerProposalsCompanion(
        status: const Value('dismissed'),
        syncState: const Value('dirty'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Soft-delete a proposal by marking syncState='deleted'.
  Future<void> delete(String proposalId) async {
    await (_db.update(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).write(
      PartnerProposalsCompanion(
        syncState: const Value('deleted'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  /// Reject a proposal and learn from it.
  ///
  /// Sets status to [ProposalStatus.rejected] (syncs back to sender) and
  /// stores exclusion rules derived from the task title so similar tasks are
  /// not proposed again.
  Future<void> reject(String proposalId, String taskTitle) async {
    await (_db.update(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).write(
      PartnerProposalsCompanion(
        status: const Value('rejected'),
        syncState: const Value('dirty'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
    await _storeExclusionFromTitle(taskTitle);
  }

  /// Watch the count of pending proposals (drives the nav badge).
  Stream<int> watchPendingCount() {
    return (_db.select(_db.partnerProposals)
          ..where((t) => t.status.equals('pending')))
        .watch()
        .map((rows) => rows.length);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _storeExclusionFromTitle(String taskTitle) async {
    final normalized = taskTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .trim();
    final words = normalized.split(RegExp(r'\s+'));
    const stopWords = {
      'voor',
      'naar',
      'met',
      'een',
      'het',
      'van',
      'zijn',
      'hebben',
      'worden',
      'maar',
      'ook',
      'niet',
      'door',
      'dan',
      'als',
      'nog',
      'mijn',
      'jouw',
      'ons',
      'hun',
    };
    final meaningful = words
        .where((w) => w.length >= 4 && !stopWords.contains(w))
        .take(2)
        .toList();
    final patterns = meaningful.isNotEmpty ? meaningful : [normalized];
    for (final pattern in patterns) {
      await _db
          .into(_db.exclusionRules)
          .insert(
            ExclusionRulesCompanion.insert(
              id: _uuid.v4(),
              pattern: pattern,
              createdAt: DateTime.now().toUtc(),
            ),
          );
    }
  }

  PartnerProposal _proposalFromRow(PartnerProposalRow row) {
    return PartnerProposal(
      id: row.id,
      fromParentId: row.fromParentId,
      taskTitle: row.taskTitle,
      taskNotes: row.taskNotes,
      taskCategory: TaskCategory.values.firstWhere(
        (e) => e.name == row.taskCategory,
        orElse: () => TaskCategory.other,
      ),
      taskPriority: TaskPriority.values[row.taskPriority],
      taskDueDate: row.taskDueDate,
      status: ProposalStatus.values.firstWhere(
        (e) => e.name == row.status,
        orElse: () => ProposalStatus.pending,
      ),
      receivedAt: row.receivedAt,
      updatedAt: row.updatedAt,
      autoGenerated: row.autoGenerated,
    );
  }
}
