import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/partner/services/partner_proposal_repository.dart';
import 'package:parent/todo/models/ai_suggestion.dart';
import 'package:parent/todo/services/ai_suggestion_engine.dart';
import 'package:parent/todo/services/ai_suggestion_repository.dart';
import 'package:parent/todo/services/todo_repository.dart';
import '../../helpers/test_database.dart';

Future<void> _insertCompletedTask(
  AppDatabase db, {
  required String id,
  required String title,
  required DateTime completedAt,
  String category = 'other',
  bool isPrivate = false,
  String? recurrenceRule,
}) async {
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
          updatedAt: Value(completedAt.toUtc()),
        ),
      );
}

Future<void> _insertOpenTask(
  AppDatabase db, {
  required String id,
  required String title,
  String category = 'other',
  bool isPrivate = false,
  DateTime? createdAt,
  DateTime? dueDate,
}) async {
  final ts = (createdAt ?? DateTime.now()).toUtc();
  await db
      .into(db.personalTasks)
      .insert(
        PersonalTasksCompanion(
          id: Value(id),
          title: Value(title),
          isCompleted: const Value(false),
          category: Value(category),
          isPrivate: Value(isPrivate),
          dueDate: Value(dueDate),
          createdAt: Value(ts),
          updatedAt: Value(ts),
        ),
      );
}

void main() {
  group('AiSuggestionEngine', () {
    late AppDatabase db;
    late AiSuggestionRepository suggestionRepo;
    late TodoRepository todoRepo;
    late DateTime testNow;

    setUp(() {
      db = createTestDatabase();
      suggestionRepo = AiSuggestionRepository(db);
      todoRepo = TodoRepository(db: db);
      testNow = DateTime.utc(2026, 6, 15, 12);
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
      now: () => testNow,
    );

    PartnerProposalRepository _proposalRepo() =>
        PartnerProposalRepository(db: db, todoRepository: todoRepo);

    group('habit detector', () {
      test('creates suggestion when median interval is exceeded', () async {
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 95)),
        );
        await _insertCompletedTask(
          db,
          id: 'h2',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 65)),
        );
        await _insertCompletedTask(
          db,
          id: 'h3',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 35)),
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 1);
        final suggestions = await suggestionRepo.watchPending().first;
        expect(suggestions.first.reason, SuggestionReason.habit);
        expect(suggestions.first.title, 'Boodschappen doen');
      });

      test('suggests after one completion of a strong habit keyword', () async {
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen',
          completedAt: testNow.subtract(const Duration(days: 20)),
        );

        await _engine().runIfDue();

        final suggestions = await suggestionRepo.watchPendingSelf().first;
        expect(suggestions, hasLength(1));
        expect(suggestions.first.reason, SuggestionReason.habit);
      });

      test('does not suggest a single weak-keyword completion', () async {
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Eenmalige klus',
          completedAt: testNow.subtract(const Duration(days: 20)),
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });

      test('does not suggest when interval not yet exceeded', () async {
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 70)),
        );
        await _insertCompletedTask(
          db,
          id: 'h2',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 40)),
        );
        await _insertCompletedTask(
          db,
          id: 'h3',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 10)),
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });

      test('does not suggest when open task with same title exists', () async {
        await _insertCompletedTask(
          db,
          id: 'h1',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 95)),
        );
        await _insertCompletedTask(
          db,
          id: 'h2',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 65)),
        );
        await _insertCompletedTask(
          db,
          id: 'h3',
          title: 'Boodschappen doen',
          completedAt: testNow.subtract(const Duration(days: 35)),
        );
        await _insertOpenTask(db, id: 'o1', title: 'Boodschappen doen');

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });

      test('does not suggest recurring tasks', () async {
        await _insertCompletedTask(
          db,
          id: 'r1',
          title: 'Medicijnen innemen',
          completedAt: testNow.subtract(const Duration(days: 60)),
          recurrenceRule: 'FREQ=DAILY',
        );
        await _insertCompletedTask(
          db,
          id: 'r2',
          title: 'Medicijnen innemen',
          completedAt: testNow.subtract(const Duration(days: 30)),
          recurrenceRule: 'FREQ=DAILY',
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });
    });

    group('seasonal detector', () {
      test('suggests task completed in same month in prior year', () async {
        final lastYear = DateTime.utc(testNow.year - 1, testNow.month, 15);
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
          final lastYear = DateTime.utc(testNow.year - 1, testNow.month, 15);
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
          final differentMonth = DateTime.utc(
            testNow.year - 1,
            (testNow.month % 12) + 1,
            10,
          );
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

    group('calendar detector', () {
      test('suggests belasting prompt in March without history', () async {
        testNow = DateTime.utc(2026, 3, 10, 12);
        await _engine().runIfDue();

        final suggestions = await suggestionRepo.watchPendingSelf().first;
        expect(
          suggestions.any((s) => s.reason == SuggestionReason.calendar),
          isTrue,
        );
        expect(
          suggestions.any((s) => s.title == 'Belastingaangifte checken'),
          isTrue,
        );
      });

      test(
        'skips calendar prompt when an open task already covers it',
        () async {
          testNow = DateTime.utc(2026, 3, 10, 12);
          await _insertOpenTask(
            db,
            id: 't1',
            title: 'Belastingaangifte indienen',
          );
          await _engine().runIfDue();

          final suggestions = await suggestionRepo.watchPendingSelf().first;
          expect(
            suggestions.any((s) => s.title == 'Belastingaangifte checken'),
            isFalse,
          );
        },
      );
    });

    group('stale detector', () {
      test('suggests a reminder for a task open longer than 7 days', () async {
        await _insertOpenTask(
          db,
          id: 'stale1',
          title: 'Oude klus',
          createdAt: testNow.subtract(const Duration(days: 10)),
        );

        await _engine().runIfDue();

        final suggestions = await suggestionRepo.watchPendingSelf().first;
        expect(suggestions, hasLength(1));
        expect(suggestions.first.reason, SuggestionReason.stale);
        expect(suggestions.first.title, 'Oude klus');
      });

      test('does not flag a fresh open task', () async {
        await _insertOpenTask(
          db,
          id: 'fresh',
          title: 'Nieuwe klus',
          createdAt: testNow.subtract(const Duration(days: 2)),
        );

        await _engine().runIfDue();

        expect(await suggestionRepo.countPending(), 0);
      });
    });

    group('load balance detector', () {
      test(
        'proposes a generic hint when ≥3 open tasks in same category',
        () async {
          await _insertOpenTask(
            db,
            id: 'lb1',
            title: 'Ramen lappen',
            category: 'household',
          );
          await _insertOpenTask(
            db,
            id: 'lb2',
            title: 'Plinten doen',
            category: 'household',
          );
          await _insertOpenTask(
            db,
            id: 'lb3',
            title: 'Deurknoppen poetsen',
            category: 'household',
          );

          await _engine(
            proposalRepo: _proposalRepo(),
            myParentId: 'parent-1',
          ).runIfDue();

          final suggestions = await suggestionRepo.watchPendingPartner().first;
          expect(suggestions, hasLength(1));
          expect(suggestions.first.reason, SuggestionReason.loadBalance);
          expect(suggestions.first.title, contains('huishouden'));
          expect(suggestions.first.title, isNot(contains('Ramen')));
          expect(suggestions.first.notes, isNull);
        },
      );

      test(
        'does not propose when fewer than 3 open tasks in a category',
        () async {
          await _insertOpenTask(
            db,
            id: 'lb1',
            title: 'Ramen lappen',
            category: 'household',
          );
          await _insertOpenTask(
            db,
            id: 'lb2',
            title: 'Plinten doen',
            category: 'household',
          );

          await _engine(
            proposalRepo: _proposalRepo(),
            myParentId: 'parent-1',
          ).runIfDue();

          final suggestions = await suggestionRepo.watchPendingPartner().first;
          expect(suggestions, isEmpty);
        },
      );

      test('counts private tasks but does not copy their titles', () async {
        await _insertOpenTask(
          db,
          id: 'lb1',
          title: 'Privé klus A',
          category: 'household',
          isPrivate: true,
        );
        await _insertOpenTask(
          db,
          id: 'lb2',
          title: 'Privé klus B',
          category: 'household',
          isPrivate: true,
        );
        await _insertOpenTask(
          db,
          id: 'lb3',
          title: 'Privé klus C',
          category: 'household',
          isPrivate: true,
        );

        await _engine(
          proposalRepo: _proposalRepo(),
          myParentId: 'parent-1',
        ).runIfDue();

        final suggestions = await suggestionRepo.watchPendingPartner().first;
        expect(suggestions, hasLength(1));
        expect(suggestions.first.reason, SuggestionReason.loadBalance);
        expect(suggestions.first.title.toLowerCase(), contains('huishouden'));
        expect(suggestions.first.title, isNot(contains('Privé')));
        expect(suggestions.first.notes, isNull);
      });
    });

    group('partner complement detector', () {
      test('maps a private school keyword to a generic partner hint', () async {
        await _insertOpenTask(
          db,
          id: 'p1',
          title: 'Afspraak GZA schoolarts 14:30',
          category: 'other',
          isPrivate: true,
        );

        await _engine(
          proposalRepo: _proposalRepo(),
          myParentId: 'parent-1',
        ).runIfDue();

        final suggestions = await suggestionRepo.watchPendingPartner().first;
        expect(suggestions, isNotEmpty);
        expect(suggestions.first.reason, SuggestionReason.partnerComplement);
        expect(suggestions.first.title, isNot(contains('GZA')));
        expect(suggestions.first.title, isNot(contains('14:30')));
        expect(suggestions.first.notes, isNull);
        expect(suggestions.first.explanation, isNot(contains('GZA')));
      });
    });

    group('throttle', () {
      test('second runIfDue within 24 hours skips self detectors', () async {
        final lastYear = DateTime.utc(testNow.year - 1, testNow.month, 15);
        await _insertCompletedTask(
          db,
          id: 's1',
          title: 'Zomerschoonmaak',
          completedAt: lastYear,
        );

        final engine = _engine();

        await engine.runIfDue();
        expect(await suggestionRepo.countPending(), 1);

        final id = (await suggestionRepo.watchPending().first).first.id;
        await suggestionRepo.dismiss(id);
        expect(await suggestionRepo.countPending(), 0);

        await engine.runIfDue();
        expect(await suggestionRepo.countPending(), 0);
      });

      test('empty run does not block a later hit', () async {
        final engine = _engine();
        await engine.runIfDue();
        expect(await suggestionRepo.countPending(), 0);

        final lastYear = DateTime.utc(testNow.year - 1, testNow.month, 15);
        await _insertCompletedTask(
          db,
          id: 's1',
          title: 'Zomerschoonmaak',
          completedAt: lastYear,
        );

        await engine.runIfDue();
        expect(await suggestionRepo.countPending(), 1);
      });
    });
  });
}
