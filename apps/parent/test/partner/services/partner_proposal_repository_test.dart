import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/partner/models/partner_proposal.dart';
import 'package:parent/partner/services/partner_proposal_repository.dart';
import 'package:parent/todo/models/enums.dart';
import 'package:parent/todo/services/todo_repository.dart';
import '../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helper — inserts a minimal PartnerProposalRow directly via the DB companion.
// ---------------------------------------------------------------------------
Future<void> _insertProposal(
  AppDatabase db, {
  required String id,
  String fromParentId = 'partner-99',
  String taskTitle = 'Test voorstel',
  String status = 'pending',
  String syncState = 'clean',
}) async {
  final now = DateTime.now().toUtc();
  await db
      .into(db.partnerProposals)
      .insert(
        PartnerProposalsCompanion.insert(
          id: id,
          fromParentId: fromParentId,
          taskTitle: taskTitle,
          status: Value(status),
          syncState: Value(syncState),
          receivedAt: now,
          updatedAt: now,
        ),
      );
}

/// Reads the raw DB row for a proposal.
Future<PartnerProposalRow?> _getRaw(AppDatabase db, String id) async {
  return (db.select(
    db.partnerProposals,
  )..where((t) => t.id.equals(id))).getSingleOrNull();
}

void main() {
  late AppDatabase db;
  late TodoRepository todoRepository;
  late PartnerProposalRepository repo;

  setUp(() {
    db = createTestDatabase();
    todoRepository = TodoRepository(db: db);
    repo = PartnerProposalRepository(db: db, todoRepository: todoRepository);
  });

  tearDown(() => db.close());

  // --------------------------------------------------------------------------
  // watchPending
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.watchPending', () {
    test('emits empty list when no proposals exist', () async {
      final proposals = await repo.watchPending().first;
      expect(proposals, isEmpty);
    });

    test('emits only pending proposals', () async {
      await _insertProposal(db, id: 'p1', status: 'pending');
      await _insertProposal(db, id: 'p2', status: 'accepted');
      await _insertProposal(db, id: 'p3', status: 'dismissed');

      final proposals = await repo.watchPending().first;
      expect(proposals, hasLength(1));
      expect(proposals.first.id, equals('p1'));
    });

    test('maps DB row to PartnerProposal correctly', () async {
      final now = DateTime.now().toUtc();
      await db
          .into(db.partnerProposals)
          .insert(
            PartnerProposalsCompanion.insert(
              id: 'mapped-1',
              fromParentId: 'partner-42',
              taskTitle: 'Afwas doen',
              taskCategory: const Value('household'),
              taskPriority: const Value(2),
              status: const Value('pending'),
              receivedAt: now,
              updatedAt: now,
            ),
          );

      final proposals = await repo.watchPending().first;
      expect(proposals, hasLength(1));
      final p = proposals.first;
      expect(p.fromParentId, equals('partner-42'));
      expect(p.taskTitle, equals('Afwas doen'));
      expect(p.taskCategory, equals(TaskCategory.household));
      expect(p.taskPriority, equals(TaskPriority.medium));
      expect(p.status, equals(ProposalStatus.pending));
    });
  });

  // --------------------------------------------------------------------------
  // watchAll
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.watchAll', () {
    test('returns proposals with any status', () async {
      await _insertProposal(db, id: 'p1', status: 'pending');
      await _insertProposal(db, id: 'p2', status: 'accepted');
      await _insertProposal(db, id: 'p3', status: 'snoozed');
      await _insertProposal(db, id: 'p4', status: 'dismissed');
      await _insertProposal(db, id: 'p5', status: 'rejected');

      final proposals = await repo.watchAll().first;
      expect(proposals, hasLength(5));
    });
  });

  // --------------------------------------------------------------------------
  // watchPendingCount
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.watchPendingCount', () {
    test('returns 0 for empty DB', () async {
      expect(await repo.watchPendingCount().first, equals(0));
    });

    test('returns count of pending proposals only', () async {
      await _insertProposal(db, id: 'p1', status: 'pending');
      await _insertProposal(db, id: 'p2', status: 'pending');
      await _insertProposal(db, id: 'p3', status: 'accepted');

      expect(await repo.watchPendingCount().first, equals(2));
    });
  });

  // --------------------------------------------------------------------------
  // accept
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.accept', () {
    test('sets status to accepted and syncState to dirty', () async {
      await _insertProposal(
        db,
        id: 'p1',
        status: 'pending',
        syncState: 'clean',
      );

      await repo.accept('p1');

      final row = await _getRaw(db, 'p1');
      expect(row?.status, equals('accepted'));
      expect(row?.syncState, equals('dirty'));
    });
  });

  // --------------------------------------------------------------------------
  // snooze
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.snooze', () {
    test('sets status to snoozed and syncState to dirty', () async {
      await _insertProposal(
        db,
        id: 'p1',
        status: 'pending',
        syncState: 'clean',
      );

      await repo.snooze('p1');

      final row = await _getRaw(db, 'p1');
      expect(row?.status, equals('snoozed'));
      expect(row?.syncState, equals('dirty'));
    });
  });

  // --------------------------------------------------------------------------
  // dismiss
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.dismiss', () {
    test('sets status to dismissed and syncState to dirty', () async {
      await _insertProposal(
        db,
        id: 'p1',
        status: 'pending',
        syncState: 'clean',
      );

      await repo.dismiss('p1');

      final row = await _getRaw(db, 'p1');
      expect(row?.status, equals('dismissed'));
      expect(row?.syncState, equals('dirty'));
    });
  });

  // --------------------------------------------------------------------------
  // delete
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.delete', () {
    test('sets syncState to deleted without changing status', () async {
      await _insertProposal(
        db,
        id: 'p1',
        status: 'pending',
        syncState: 'clean',
      );

      await repo.delete('p1');

      final row = await _getRaw(db, 'p1');
      // Row is still present (soft-delete), status unchanged
      expect(row, isNotNull);
      expect(row?.syncState, equals('deleted'));
      expect(row?.status, equals('pending'));
    });
  });

  // --------------------------------------------------------------------------
  // reject
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.reject', () {
    test('sets status to rejected and syncState to dirty', () async {
      await _insertProposal(
        db,
        id: 'p1',
        status: 'pending',
        syncState: 'clean',
      );

      await repo.reject('p1', 'Afwas doen');

      final row = await _getRaw(db, 'p1');
      expect(row?.status, equals('rejected'));
      expect(row?.syncState, equals('dirty'));
    });

    test('stores exclusion rules derived from task title', () async {
      await _insertProposal(db, id: 'p1', status: 'pending');

      await repo.reject('p1', 'Boodschappen halen');

      // 'boodschappen' and 'halen' are >= 4 chars and not stop-words
      final rules = await db.select(db.exclusionRules).get();
      expect(rules, isNotEmpty);
      final patterns = rules.map((r) => r.pattern).toList();
      expect(patterns, contains('boodschappen'));
      expect(patterns, contains('halen'));
    });

    test('falls back to full title if no meaningful words found', () async {
      await _insertProposal(db, id: 'p1', status: 'pending');

      // All words are stop-words or < 4 chars
      await repo.reject('p1', 'het een van');

      final rules = await db.select(db.exclusionRules).get();
      expect(rules, isNotEmpty);
    });

    test('stores at most 2 exclusion patterns per rejection', () async {
      await _insertProposal(db, id: 'p1', status: 'pending');

      await repo.reject('p1', 'Boodschappen halen supermarkt');

      final rules = await db.select(db.exclusionRules).get();
      // _storeExclusionFromTitle takes at most 2 meaningful words
      expect(rules.length, lessThanOrEqualTo(2));
    });
  });

  // --------------------------------------------------------------------------
  // watchOne
  // --------------------------------------------------------------------------
  group('PartnerProposalRepository.watchOne', () {
    test('emits null for unknown id', () async {
      final result = await repo.watchOne('unknown').first;
      expect(result, isNull);
    });

    test('emits the proposal for a known id', () async {
      await _insertProposal(db, id: 'p1', taskTitle: 'Ophalen kinderen');

      final result = await repo.watchOne('p1').first;
      expect(result, isNotNull);
      expect(result!.taskTitle, equals('Ophalen kinderen'));
    });
  });
}
