import 'package:flutter_test/flutter_test.dart';
import 'package:parent/db/app_database.dart';
import 'package:parent/todo/models/ai_suggestion.dart';
import 'package:parent/todo/services/ai_suggestion_repository.dart';
import '../../helpers/test_database.dart';

void main() {
  group('AiSuggestionRepository', () {
    late AppDatabase db;
    late AiSuggestionRepository repo;

    setUp(() {
      db = createTestDatabase();
      repo = AiSuggestionRepository(db);
    });

    tearDown(() async => db.close());

    // -------------------------------------------------------------------------
    // upsertSuggestion
    // -------------------------------------------------------------------------

    test('upsertSuggestion inserts a new suggestion', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(
          title: 'Boodschappen',
          reason: SuggestionReason.habit,
        ),
      );
      expect(await repo.countPending(), 1);
    });

    test(
      'upsertSuggestion deduplicates by title (case-insensitive trim)',
      () async {
        await repo.upsertSuggestion(
          AiSuggestion.create(
            title: 'Boodschappen',
            reason: SuggestionReason.habit,
          ),
        );
        await repo.upsertSuggestion(
          AiSuggestion.create(
            title: ' boodschappen ',
            reason: SuggestionReason.seasonal,
          ),
        );
        expect(await repo.countPending(), 1);
      },
    );

    test(
      'upsertSuggestion allows second suggestion with different title',
      () async {
        await repo.upsertSuggestion(
          AiSuggestion.create(
            title: 'Boodschappen',
            reason: SuggestionReason.habit,
          ),
        );
        await repo.upsertSuggestion(
          AiSuggestion.create(title: 'Sporten', reason: SuggestionReason.habit),
        );
        expect(await repo.countPending(), 2);
      },
    );

    // -------------------------------------------------------------------------
    // watchPending / countPending
    // -------------------------------------------------------------------------

    test('watchPending emits all pending suggestions', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'Taak A', reason: SuggestionReason.habit),
      );
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'Taak B', reason: SuggestionReason.seasonal),
      );
      final pending = await repo.watchPending().first;
      expect(pending, hasLength(2));
    });

    test('watchPending excludes dismissed suggestions', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'Koken', reason: SuggestionReason.habit),
      );
      final id = (await repo.watchPending().first).first.id;
      await repo.dismiss(id);
      expect(await repo.watchPending().first, isEmpty);
    });

    test('watchPending excludes accepted suggestions', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'School', reason: SuggestionReason.habit),
      );
      final id = (await repo.watchPending().first).first.id;
      await repo.accept(id);
      expect(await repo.watchPending().first, isEmpty);
    });

    test('watchPending excludes snoozed suggestions', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'Sporten', reason: SuggestionReason.habit),
      );
      final id = (await repo.watchPending().first).first.id;
      await repo.snooze(id);
      expect(await repo.watchPending().first, isEmpty);
    });

    test('countPending returns 0 when all dismissed', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(
          title: 'Vakantie',
          reason: SuggestionReason.seasonal,
        ),
      );
      final id = (await repo.watchPending().first).first.id;
      await repo.dismiss(id);
      expect(await repo.countPending(), 0);
    });

    test('watchPendingCount emits pending suggestion count', () async {
      expect(await repo.watchPendingCount().first, 0);
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'Taak A', reason: SuggestionReason.habit),
      );
      await repo.upsertSuggestion(
        AiSuggestion.create(title: 'Taak B', reason: SuggestionReason.seasonal),
      );
      expect(await repo.watchPendingCount().first, 2);
    });

    // -------------------------------------------------------------------------
    // snooze
    // -------------------------------------------------------------------------

    test(
      'snooze sets status=snoozed and snoozeUntil ~7 days from now',
      () async {
        await repo.upsertSuggestion(
          AiSuggestion.create(
            title: 'Administratie',
            reason: SuggestionReason.habit,
          ),
        );
        final id = (await repo.watchPending().first).first.id;
        await repo.snooze(id);

        final rows = await db.select(db.aiSuggestions).get();
        final row = rows.first;
        expect(row.status, 'snoozed');
        expect(row.snoozeUntil, isNotNull);
        expect(
          row.snoozeUntil!.difference(DateTime.now().toUtc()).inDays,
          closeTo(7, 1),
        );
      },
    );

    // -------------------------------------------------------------------------
    // hasPendingWithTitle
    // -------------------------------------------------------------------------

    test(
      'hasPendingWithTitle returns true for existing pending suggestion',
      () async {
        await repo.upsertSuggestion(
          AiSuggestion.create(
            title: 'Tandenpoetsen',
            reason: SuggestionReason.habit,
          ),
        );
        expect(await repo.hasPendingWithTitle('Tandenpoetsen'), isTrue);
      },
    );

    test(
      'hasPendingWithTitle returns true for snoozed suggestion (blocks re-insert)',
      () async {
        await repo.upsertSuggestion(
          AiSuggestion.create(
            title: 'Tandenpoetsen',
            reason: SuggestionReason.habit,
          ),
        );
        final id = (await repo.watchPending().first).first.id;
        await repo.snooze(id);
        expect(await repo.hasPendingWithTitle('Tandenpoetsen'), isTrue);
      },
    );

    test('hasPendingWithTitle returns false after dismiss', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(
          title: 'Tandenpoetsen',
          reason: SuggestionReason.habit,
        ),
      );
      final id = (await repo.watchPending().first).first.id;
      await repo.dismiss(id);
      expect(await repo.hasPendingWithTitle('Tandenpoetsen'), isFalse);
    });

    test('hasPendingWithTitle returns false after accept', () async {
      await repo.upsertSuggestion(
        AiSuggestion.create(
          title: 'Tandenpoetsen',
          reason: SuggestionReason.habit,
        ),
      );
      final id = (await repo.watchPending().first).first.id;
      await repo.accept(id);
      expect(await repo.hasPendingWithTitle('Tandenpoetsen'), isFalse);
    });
  });
}
