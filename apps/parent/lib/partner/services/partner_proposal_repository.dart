import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../todo/models/enums.dart';
import '../../todo/services/todo_repository.dart';
import '../models/partner_proposal.dart';

/// PartnerProposalRepository — CRUD for inter-parent task proposals.
///
/// Manages proposals from the other parent, supporting accept/snooze/dismiss workflow.
class PartnerProposalRepository {
  final AppDatabase _db;
  final TodoRepository _todoRepository;
  final _uuid = const Uuid();

  PartnerProposalRepository({
    required AppDatabase db,
    required TodoRepository todoRepository,
  }) : _db = db,
       _todoRepository = todoRepository;

  /// All pending proposals from the partner, ordered by received date (newest first).
  ///
  /// [myParentId] is used to exclude proposals sent by the local user so they
  /// do not appear in their own inbox.
  /// Also filters out proposals whose task title closely matches a task already
  /// present in the local personal task list (receiver already has the task).
  Stream<List<PartnerProposal>> watchPending({String? myParentId}) {
    final proposalsStream =
        (_db.select(_db.partnerProposals)
              ..where((t) => t.status.equals('pending'))
              ..orderBy([(t) => OrderingTerm.desc(t.receivedAt)]))
            .watch()
            .map(
              (rows) => rows
                  .where(
                    (r) => myParentId == null || r.fromParentId != myParentId,
                  )
                  .map(_proposalFromRow)
                  .toList(),
            );

    final tasksStream =
        (_db.select(_db.personalTasks)..where(
              (t) =>
                  t.isCompleted.equals(false) &
                  t.syncState.equals('deleted').not(),
            ))
            .watch();

    return proposalsStream.asyncExpand(
      (proposals) => tasksStream.map((taskRows) {
        final ownTitles = taskRows.map((r) => _normalizeTitle(r.title)).toSet();
        return proposals
            .where((p) => !ownTitles.contains(_normalizeTitle(p.taskTitle)))
            .toList();
      }),
    );
  }

  static String _normalizeTitle(String title) =>
      title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

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

  /// Accept a proposal: create a task from the proposal and update status.
  Future<void> accept(String proposalId) async {
    // Fetch the proposal to get task details
    final proposalRow = await (_db.select(
      _db.partnerProposals,
    )..where((t) => t.id.equals(proposalId))).getSingleOrNull();

    if (proposalRow == null) {
      throw StateError('Proposal $proposalId not found');
    }

    // Create a personal task from the proposal
    await _todoRepository.createTask(
      title: proposalRow.taskTitle,
      notes: proposalRow.taskNotes,
      category:
          TaskCategory.other, // Use default category for accepted proposals
      priority: TaskPriority.values[proposalRow.taskPriority],
      dueDate: proposalRow.taskDueDate,
      isPrivate: true, // Accepted proposals become personal tasks
    );

    // Update proposal status to 'accepted'
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

  /// Watch the count of pending proposals from the partner (drives the nav badge).
  ///
  /// [myParentId] excludes own outgoing proposals from the count.
  Stream<int> watchPendingCount({String? myParentId}) {
    return (_db.select(
      _db.partnerProposals,
    )..where((t) => t.status.equals('pending'))).watch().map(
      (rows) => rows
          .where((r) => myParentId == null || r.fromParentId != myParentId)
          .length,
    );
  }

  /// Watch the status of an outgoing proposal for the given task title sent
  /// by [fromParentId].  Returns null when no matching proposal exists.
  /// Returns [ProposalStatus.pending] when the proposal is active,
  /// [ProposalStatus.rejected] or [ProposalStatus.dismissed] when declined.
  Stream<ProposalStatus?> watchOutgoingProposalStatus({
    required String taskTitle,
    required String fromParentId,
  }) {
    final normalized = _normalizeTitle(taskTitle);
    return (_db.select(_db.partnerProposals)
          ..where((p) => p.fromParentId.equals(fromParentId))
          ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
        .watch()
        .map((rows) {
          for (final r in rows) {
            if (_normalizeTitle(r.taskTitle) == normalized) {
              return ProposalStatus.values.firstWhere(
                (s) => s.name == r.status,
                orElse: () => ProposalStatus.pending,
              );
            }
          }
          return null;
        });
  }

  /// Returns accepted proposals (for the AI engine to analyse).
  Stream<List<PartnerProposalRow>> watchAccepted() {
    return (_db.select(
      _db.partnerProposals,
    )..where((p) => p.status.equals('accepted'))).watch();
  }

  /// Returns true if an outgoing proposal with [title] from [parentId] was
  /// created in the last 30 days (dedup for auto proposals).
  Future<bool> hasRecentOutgoing(String title, String parentId) async {
    final cutoff = DateTime.now().toUtc().subtract(const Duration(days: 30));
    final normalized = _normalizeTitle(title);
    final rows =
        await (_db.select(_db.partnerProposals)..where(
              (p) =>
                  p.fromParentId.equals(parentId) &
                  p.syncState.equals('deleted').not() &
                  p.receivedAt.isBiggerOrEqualValue(cutoff),
            ))
            .get();
    return rows.any((r) => _normalizeTitle(r.taskTitle) == normalized);
  }

  /// Check if a task was accepted from a partner proposal.
  /// Returns true when the task title matches an accepted proposal from a partner.
  Stream<bool> watchAcceptedProposalForTask({required String taskTitle}) {
    final normalized = _normalizeTitle(taskTitle);
    return (_db.select(
      _db.partnerProposals,
    )..where((p) => p.status.equals('accepted'))).watch().map((rows) {
      for (final r in rows) {
        if (_normalizeTitle(r.taskTitle) == normalized) {
          return true;
        }
      }
      return false;
    });
  }

  /// Manually send a task to your partner.
  ///
  /// Creates a proposal (autoGenerated=false) with the task's data so the
  /// partner sees it in their Partner inbox.  The task itself is NOT deleted
  /// here — the caller is responsible for soft-deleting it after calling this.
  Future<void> createManualProposal({
    required String myParentId,
    required String taskTitle,
    String? taskNotes,
    required TaskPriority taskPriority,
    DateTime? taskDueDate,
  }) async {
    final now = DateTime.now().toUtc();
    await _db
        .into(_db.partnerProposals)
        .insert(
          PartnerProposalsCompanion.insert(
            id: _uuid.v4(),
            fromParentId: myParentId,
            taskTitle: taskTitle,
            taskNotes: Value(taskNotes),
            taskCategory: const Value('other'),
            taskPriority: Value(taskPriority.index),
            taskDueDate: Value(taskDueDate),
            status: const Value('pending'),
            autoGenerated: const Value(false),
            syncState: const Value('dirty'),
            receivedAt: now,
            updatedAt: now,
          ),
        );
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
      taskCategory: row.taskCategory,
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
