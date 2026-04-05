import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/partner/services/proposal_analyzer.dart';
import '../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helpers — insert task / proposal rows for test setup.
// ---------------------------------------------------------------------------

Future<void> _insertTask(
  AppDatabase db, {
  required String id,
  required String title,
  bool isCompleted = false,
  bool isPrivate = false,
  DateTime? dueDate,
  String category = 'household',
}) async {
  final now = DateTime.now().toUtc();
  await db.into(db.personalTasks).insert(
    PersonalTasksCompanion.insert(
      id: id,
      title: title,
      isCompleted: Value(isCompleted),
      isPrivate: Value(isPrivate),
      dueDate: Value(dueDate),
      category: Value(category),
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> _insertProposal(
  AppDatabase db, {
  required String id,
  required String fromParentId,
  required String taskTitle,
  required DateTime receivedAt,
}) async {
  await db.into(db.partnerProposals).insert(
    PartnerProposalsCompanion.insert(
      id: id,
      fromParentId: fromParentId,
      taskTitle: taskTitle,
      receivedAt: receivedAt,
      updatedAt: receivedAt,
    ),
  );
}

void main() {
  late AppDatabase db;
  late ProposalAnalyzer analyzer;

  const selfId = 'parent-self';

  setUp(() {
    db = createTestDatabase();
    analyzer = ProposalAnalyzer(db: db);
  });

  tearDown(() => db.close());

  // --------------------------------------------------------------------------
  // Edge cases
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — edge cases', () {
    test('returns empty list when selfId is empty', () async {
      await _insertTask(db, id: 't1', title: 'Boodschappen halen');

      final candidates = await analyzer.findCandidates('');
      expect(candidates, isEmpty);
    });

    test('returns empty list when no tasks exist', () async {
      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });

    test('returns empty list when all tasks score below threshold', () async {
      // category=health has base score 15, no keyword boost → 15 < 55
      await _insertTask(db, id: 't1', title: 'Yoga', category: 'health');

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });
  });

  // --------------------------------------------------------------------------
  // Eligibility filters
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — eligibility filters', () {
    test('skips completed tasks', () async {
      // household base = 65 → passes threshold if not completed
      await _insertTask(
        db,
        id: 't1',
        title: 'Afwas doen',
        category: 'household',
        isCompleted: true,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });

    test('skips private tasks', () async {
      await _insertTask(
        db,
        id: 't1',
        title: 'Afwas doen',
        category: 'household',
        isPrivate: true,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });

    test('skips tasks due within 24 hours', () async {
      final soon = DateTime.now().toUtc().add(const Duration(hours: 12));
      await _insertTask(
        db,
        id: 't1',
        title: 'Afwas doen',
        category: 'household',
        dueDate: soon,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });

    test('includes tasks without a due date', () async {
      // No dueDate → eligible (dueDate.isNull() condition passes)
      await _insertTask(db, id: 't1', title: 'Afwas doen', category: 'household');

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isNotEmpty);
    });

    test('includes tasks due more than 24 hours from now', () async {
      final future = DateTime.now().toUtc().add(const Duration(hours: 48));
      await _insertTask(
        db,
        id: 't1',
        title: 'Afwas doen',
        category: 'household',
        dueDate: future,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isNotEmpty);
    });
  });

  // --------------------------------------------------------------------------
  // Scoring — category base scores
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — category scoring', () {
    test('household tasks pass threshold (base=65)', () async {
      await _insertTask(db, id: 't1', title: 'Schoonmaken', category: 'household');
      expect(await analyzer.findCandidates(selfId), isNotEmpty);
    });

    test('admin tasks pass threshold (base=60)', () async {
      await _insertTask(db, id: 't1', title: 'Documenten regelen', category: 'admin');
      expect(await analyzer.findCandidates(selfId), isNotEmpty);
    });

    test('school tasks pass threshold (base=55)', () async {
      await _insertTask(db, id: 't1', title: 'Toestemming formulier', category: 'school');
      expect(await analyzer.findCandidates(selfId), isNotEmpty);
    });

    test('finance tasks do NOT pass threshold alone (base=40)', () async {
      await _insertTask(db, id: 't1', title: 'Rekeningen', category: 'finance');
      expect(await analyzer.findCandidates(selfId), isEmpty);
    });

    test('health tasks do NOT pass threshold alone (base=15)', () async {
      await _insertTask(db, id: 't1', title: 'Dokter bellen', category: 'health');
      // 'bellen' is a boost keyword → 15 + 20 = 35 — still < 55
      expect(await analyzer.findCandidates(selfId), isEmpty);
    });
  });

  // --------------------------------------------------------------------------
  // Scoring — keyword boost
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — keyword boost', () {
    test('boost keyword lifts otherwise failing finance task over threshold', () async {
      // finance base=40, 'ophalen' boost=+20 → 60 >= 55
      await _insertTask(
        db,
        id: 't1',
        title: 'Pakket ophalen',
        category: 'finance',
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, hasLength(1));
      expect(candidates.first.id, equals('t1'));
    });

    test('keyword boost is applied at most once per task', () async {
      // Even if multiple keywords match, only +20 is added.
      // finance base=40, max +20 → 60 (not 80 or more)
      await _insertTask(
        db,
        id: 't1',
        title: 'Boodschappen ophalen supermarkt',
        category: 'finance',
      );
      // The task should still appear exactly once
      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, hasLength(1));
    });
  });

  // --------------------------------------------------------------------------
  // Scoring — exclusion penalty
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — exclusion penalty', () {
    test('exclusion rule reduces score and filters task below threshold', () async {
      // household base=65, exclusion penalty=40 → 65-40=25 < 55
      await _insertTask(db, id: 't1', title: 'Afwas', category: 'household');
      final now = DateTime.now().toUtc();
      await db.into(db.exclusionRules).insert(
        ExclusionRulesCompanion.insert(
          id: 'rule-1',
          pattern: 'afwas',
          createdAt: now,
        ),
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });

    test('multiple exclusion rules stack their penalties', () async {
      await _insertTask(
        db,
        id: 't1',
        title: 'Boodschappen ophalen',
        category: 'finance', // base=40, boost=+20 → 60
      );
      final now = DateTime.now().toUtc();
      // Two penalties of 40 each: 60 - 40 - 40 = -20 < 55
      await db.into(db.exclusionRules).insert(
        ExclusionRulesCompanion.insert(id: 'r1', pattern: 'boodschappen', createdAt: now),
      );
      await db.into(db.exclusionRules).insert(
        ExclusionRulesCompanion.insert(id: 'r2', pattern: 'ophalen', createdAt: now),
      );

      expect(await analyzer.findCandidates(selfId), isEmpty);
    });
  });

  // --------------------------------------------------------------------------
  // Deduplication
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — deduplication', () {
    test('skips tasks recently proposed by this parent (within 14 days)', () async {
      await _insertTask(db, id: 't1', title: 'Afwas doen', category: 'household');
      // Insert a recent proposal with the same normalized title from this parent
      final recentDate = DateTime.now().toUtc().subtract(const Duration(days: 7));
      await _insertProposal(
        db,
        id: 'prop-1',
        fromParentId: selfId,
        taskTitle: 'Afwas doen',
        receivedAt: recentDate,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isEmpty);
    });

    test('includes task if same proposal was sent >14 days ago', () async {
      await _insertTask(db, id: 't1', title: 'Afwas doen', category: 'household');
      final oldDate = DateTime.now().toUtc().subtract(const Duration(days: 15));
      await _insertProposal(
        db,
        id: 'prop-1',
        fromParentId: selfId,
        taskTitle: 'Afwas doen',
        receivedAt: oldDate,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isNotEmpty);
    });

    test('deduplication is NOT applied for proposals from partner (different parentId)', () async {
      await _insertTask(db, id: 't1', title: 'Afwas doen', category: 'household');
      final recentDate = DateTime.now().toUtc().subtract(const Duration(days: 3));
      // Proposal is from the partner, not from selfId
      await _insertProposal(
        db,
        id: 'prop-1',
        fromParentId: 'partner-other',
        taskTitle: 'Afwas doen',
        receivedAt: recentDate,
      );

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates, isNotEmpty);
    });
  });

  // --------------------------------------------------------------------------
  // Max candidates
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.findCandidates — max candidates', () {
    test('returns at most 3 candidates', () async {
      for (var i = 0; i < 6; i++) {
        await _insertTask(db, id: 't$i', title: 'Afwas $i', category: 'household');
      }

      final candidates = await analyzer.findCandidates(selfId);
      expect(candidates.length, lessThanOrEqualTo(3));
    });
  });

  // --------------------------------------------------------------------------
  // storeExclusionFromTitle
  // --------------------------------------------------------------------------
  group('ProposalAnalyzer.storeExclusionFromTitle', () {
    test('stores meaningful words from title as exclusion patterns', () async {
      await analyzer.storeExclusionFromTitle('Boodschappen halen');

      final rules = await db.select(db.exclusionRules).get();
      final patterns = rules.map((r) => r.pattern).toSet();
      expect(patterns, contains('boodschappen'));
      expect(patterns, contains('halen'));
    });

    test('ignores stop-words and words shorter than 4 chars', () async {
      await analyzer.storeExclusionFromTitle('het van een');

      final rules = await db.select(db.exclusionRules).get();
      // No meaningful words → stores full normalized title
      expect(rules, isNotEmpty);
    });

    test('stores at most 2 patterns per call', () async {
      await analyzer.storeExclusionFromTitle('Boodschappen ophalen supermarkt winkel');

      final rules = await db.select(db.exclusionRules).get();
      expect(rules.length, lessThanOrEqualTo(2));
    });

    test('exclusion patterns influence subsequent findCandidates calls', () async {
      await _insertTask(db, id: 't1', title: 'Afwas doen', category: 'household');

      // Without exclusion: task is found
      expect(await analyzer.findCandidates(selfId), hasLength(1));

      // After storing exclusion for 'afwas' (penalty=40 → 65-40=25 < 55)
      await analyzer.storeExclusionFromTitle('afwas doen');

      // Now the task should be filtered out
      expect(await analyzer.findCandidates(selfId), isEmpty);
    });
  });
}
