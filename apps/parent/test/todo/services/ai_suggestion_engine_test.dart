import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/partner/services/partner_proposal_repository.dart';
import 'package:parent/todo/models/ai_suggestion.dart';
import 'package:parent/todo/services/ai_suggestion_engine.dart';
import 'package:parent/todo/services/ai_suggestion_repository.dart';
import 'package:parent/todo/services/todo_repository.dart';
import '../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helpers — insert task rows with controlled dates directly into the DB.
// ---------------------------------------------------------------------------

Future<void> _insertCompletedTask(
  AppDatabase db, {
  required String id,
  required String title,
  required DateTime completedAt,
  String category = 'other',
  bool isPrivate = false,
  String? recurrenceRule,
}) async {
  final now = DateTime.now().toUtc();
  await db
      .into(db.personalTasks)
      .insert(
        PersonalTasksCompanion(
          id: Value(id),
          title: Value(title),
          isCompleted: const Value(true),
          completedAt: Value(completedAt.toUtc()),
          category: Value(category),
          isPrivate: Value(isPrivate),
          recurrenceRule: Value(recurrenceRule),
          createdAt: Value(completedAt.toUtc()),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _insertOpenTask(
  AppDatabase db, {
  required String id,
  required String title,
  String category = 'other',
  bool isPrivate = false,
}) async {
  final now = DateTime.now().toUtc();
  await db
      .into(db.personalTasks)
      .insert(
        PersonalTasksCompanion(
          id: Value(id),
          title: Value(title),
          isCompleted: const Value(false),
          category: Value(category),
          isPrivate: Value(isPrivate),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

// ---------------------------------------------------------------------------

void main() {
  group('AiSuggestionEngine', () {
    late AppDatabase db;
    late AiSuggestionRepository suggestionRepo;
    late TodoRepository todoRepo;

    setUp(() {
      db = createTestDatabase();
      suggestionRepo = AiSuggestionRepository(db);
      todoRepo = TodoRepository(db: db);
    });

    tearDown(() async => db.close());

    AiSuggestionEngine _engine({
      PartnerProposalRepository? proposalRepo,
      String? myParentId,
    }) => AiSuggestionEngine(
      db: db,
      suggestionRepo: suggestionRepo,
      todoRepo: todoRepo,
      proposalRepo: proposalRepo,
      myParentId: myParentId,
    );

    // -----------------------------------------------------------------------
    // Habit detector
    // -----------------------------------------------------------------------

    group('habit detector', () {
      test('creates suggestion when median interval is exceeded', () async {
        final now = DateTime.now().toUtc();
        // 3 completions ~30 days apart; last was 35 days ago → 35 > 30 * 0.8 = 24
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 95)),
        );
        await _insertCompletedTask(
          db,
          id: 'h2',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 65)),
        );
        await _insertCompletedTask(
          db,
          id: 'h3',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 35)),
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 1);
        final suggestions = await suggestionRepo.watchPending().first;
        expect(suggestions.first.reason, SuggestionReason.habit);
        expect(suggestions.first.title, 'Boodschappen doen');
      });

      test('does not suggest when interval not yet exceeded', () async {
        final now = DateTime.now().toUtc();
        // Last completion was only 10 days ago; median ~30 → 10 < 24 → skip
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 70)),
        );
        await _insertCompletedTask(
          db,
          id: 'h2',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 40)),
        );
        await _insertCompletedTask(
          db,
          id: 'h3',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 10)),
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });

      test('does not suggest when open task with same title exists', () async {
        final now = DateTime.now().toUtc();
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 95)),
        );
        await _insertCompletedTask(
          db,
          id: 'h2',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 65)),
        );
        await _insertCompletedTask(
          db,
          id: 'h3',
          title: 'Boodschappen doen',
          completedAt: now.subtract(const Duration(days: 35)),
        );
        await _insertOpenTask(db, id: 'o1', title: 'Boodschappen doen');

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });

      test(
        'does not suggest when only one completion (no interval to compute)',
        () async {
          final now = DateTime.now().toUtc();
          await _insertCompletedTask(
            db,
            id: 'h1',
            title: 'Eenmalige taak',
            completedAt: now.subtract(const Duration(days: 50)),
          );

          await _engine().runIfDue();

          expect(await suggestionRepo.countPending(), 0);
        },
      );

      test('does not suggest recurring tasks', () async {
        final now = DateTime.now().toUtc();
        await _insertCompletedTask(
          db,
          id: 'r1',
          title: 'Medicijnen innemen',
          completedAt: now.subtract(const Duration(days: 60)),
          recurrenceRule: 'FREQ=DAILY',
        );
        await _insertCompletedTask(
          db,
          id: 'r2',
          title: 'Medicijnen innemen',
          completedAt: now.subtract(const Duration(days: 30)),
          recurrenceRule: 'FREQ=DAILY',
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });
    });

    // -----------------------------------------------------------------------
    // Seasonal detector
    // -----------------------------------------------------------------------

    group('seasonal detector', () {
      test('suggests task completed in same month in prior year', () async {
        final now = DateTime.now().toUtc();
        final lastYear = DateTime(now.year - 1, now.month, 15).toUtc();
        await _insertCompletedTask(
          db,
          id: 's1',
          title: 'Zomerschoonmaak',
          completedAt: lastYear,
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 1);
        final suggestions = await suggestionRepo.watchPending().first;
        expect(suggestions.first.reason, SuggestionReason.seasonal);
        expect(suggestions.first.title, 'Zomerschoonmaak');
      });

      test(
        'does not suggest when open task with same title already exists',
        () async {
          final now = DateTime.now().toUtc();
          final lastYear = DateTime(now.year - 1, now.month, 15).toUtc();
          await _insertCompletedTask(
            db,
            id: 's1',
            title: 'Zomerschoonmaak',
            completedAt: lastYear,
          );
          await _insertOpenTask(db, id: 'o1', title: 'Zomerschoonmaak');

          await _engine().runIfDue();

          expect(await suggestionRepo.countPending(), 0);
        },
      );

      test(
        'does not suggest task completed in a different month last year',
        () async {
          final now = DateTime.now().toUtc();
          final differentMonth = DateTime(
            now.year - 1,
            (now.month % 12) + 1,
            10,
          ).toUtc();
          await _insertCompletedTask(
            db,
            id: 's1',
            title: 'Jaarschoonmaak',
            completedAt: differentMonth,
          );

          await _engine().runIfDue();

          expect(await suggestionRepo.countPending(), 0);
        },
      );
    });

    // -----------------------------------------------------------------------
    // Load balance detector (partner path)
    // -----------------------------------------------------------------------

    group('load balance detector', () {
      test(
        'proposes oldest task to partner when ≥3 open tasks in same category',
        () async {
          final proposalRepo = PartnerProposalRepository(
            db: db,
            todoRepository: todoRepo,
          );

          await _insertOpenTask(
            db,
            id: 'lb1',
            title: 'Afwas doen',
            category: 'household',
          );
          await _insertOpenTask(
            db,
            id: 'lb2',
            title: 'Stofzuigen',
            category: 'household',
          );
          await _insertOpenTask(
            db,
            id: 'lb3',
            title: 'Ramen lappen',
            category: 'household',
          );

          await _engine(
            proposalRepo: proposalRepo,
            myParentId: 'parent-1',
          ).runIfDue();

          final suggestions = await suggestionRepo.watchPendingPartner().first;
          expect(suggestions, hasLength(1));
          expect(suggestions.first.reason, SuggestionReason.loadBalance);
        },
      );

      test(
        'does not propose when fewer than 3 open tasks in a category',
        () async {
          final proposalRepo = PartnerProposalRepository(
            db: db,
            todoRepository: todoRepo,
          );

          await _insertOpenTask(
            db,
            id: 'lb1',
            title: 'Afwas doen',
            category: 'household',
          );
          await _insertOpenTask(
            db,
            id: 'lb2',
            title: 'Stofzuigen',
            category: 'household',
          );

          await _engine(
            proposalRepo: proposalRepo,
            myParentId: 'parent-1',
          ).runIfDue();

          final suggestions = await suggestionRepo.watchPendingPartner().first;
          expect(suggestions, isEmpty);
        },
      );

      test('does not propose private tasks', () async {
        final proposalRepo = PartnerProposalRepository(
          db: db,
          todoRepository: todoRepo,
        );

        await _insertOpenTask(
          db,
          id: 'lb1',
          title: 'Afwas doen',
          category: 'household',
          isPrivate: true,
        );
        await _insertOpenTask(
          db,
          id: 'lb2',
          title: 'Stofzuigen',
          category: 'household',
          isPrivate: true,
        );
        await _insertOpenTask(
          db,
          id: 'lb3',
          title: 'Ramen lappen',
          category: 'household',
          isPrivate: true,
        );

        await _engine(
          proposalRepo: proposalRepo,
          myParentId: 'parent-1',
        ).runIfDue();

        final suggestions = await suggestionRepo.watchPendingPartner().first;
        expect(suggestions, isEmpty);
      });
    });

    // -----------------------------------------------------------------------
    // Throttle
    // -----------------------------------------------------------------------

    group('throttle', () {
      test('second runIfDue within 24 hours skips self detectors', () async {
        final now = DateTime.now().toUtc();
        final lastYear = DateTime(now.year - 1, now.month, 15).toUtc();
        await _insertCompletedTask(
          db,
          id: 's1',
          title: 'Zomerschoonmaak',
          completedAt: lastYear,
        );

        final engine = _engine();

        // First run → creates suggestion, sets lastSuggestionRunAt = now
        await engine.runIfDue();
        expect(await suggestionRepo.countPending(), 1);

        // Dismiss the suggestion so it doesn't block new ones
        final id = (await suggestionRepo.watchPending().first).first.id;
        await suggestionRepo.dismiss(id);
        expect(await suggestionRepo.countPending(), 0);

        // Second run immediately → should be throttled (< 24 h since last run)
        await engine.runIfDue();
        expect(await suggestionRepo.countPending(), 0);
      });
    });
  });
}
