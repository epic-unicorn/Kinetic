import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../todo/models/enums.dart';
import '../models/partner_proposal.dart';

/// PartnerProposalRepository — CRUD for inter-parent task proposals.
///
/// Manages proposals from the other parent, supporting accept/snooze/dismiss workflow.
class PartnerProposalRepository {
  final AppDatabase _db;

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

  // ── Helpers ────────────────────────────────────────────────────────────────

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
    );
  }
}
