import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../db/app_database.dart';
import '../../todo/models/enums.dart';

/// ProposalAnalyzer — scores the local task list for shareability and returns
/// candidates to be proposed to the partner.
///
/// Scoring is entirely on-device using Dutch keyword heuristics and learned
/// exclusion rules (stored via [storeExclusionFromTitle]).
class ProposalAnalyzer {
  final AppDatabase _db;

  ProposalAnalyzer({required AppDatabase db}) : _db = db;

  // ── Tuning constants ────────────────────────────────────────────────────────

  static const _threshold = 55;
  static const _maxPerCycle = 3;
  static const _deduplicationDays = 14;

  /// Dutch keywords/phrases that suggest a task is easily delegable.
  static const _boostKeywords = [
    'ophalen',
    'halen',
    'brengen',
    'bellen',
    'mailen',
    'regelen',
    'betalen',
    'overmaken',
    'bestellen',
    'aanvragen',
    'invullen',
    'inleveren',
    'afspraak',
    'dokter',
    'tandarts',
    'school',
    'boodschappen',
    'supermarkt',
    'winkel',
    'kopen',
    'terugbellen',
    'reserveren',
    'boeken',
    'afmelden',
    'aanmelden',
    'sorteren',
    'opruimen',
    'schoonmaken',
    'repareren',
    'regelen',
    'afleveren',
    'ophangen',
    'verlengen',
    'vernieuwen',
    'inschrijven',
  ];

  /// Base shareability score per category (0–100).
  static const _categoryScores = {
    TaskCategory.household: 65,
    TaskCategory.admin: 60,
    TaskCategory.school: 55,
    TaskCategory.finance: 40,
    TaskCategory.health: 15,
    TaskCategory.other: 30,
  };

  // ── Public API ───────────────────────────────────────────────────────────────

  /// Returns up to [_maxPerCycle] task rows that are good proposal candidates.
  ///
  /// [myParentId] is used to dedup against proposals already sent by this
  /// parent in the last [_deduplicationDays] days.
  Future<List<PersonalTaskRow>> findCandidates(String myParentId) async {
    if (myParentId.isEmpty) return [];

    final now = DateTime.now().toUtc();
    final urgentCutoff = now.add(const Duration(hours: 24));

    // 1. Eligible tasks: non-private, non-completed, not due within 24 h.
    final rows =
        await (_db.select(_db.personalTasks)..where(
              (t) =>
                  t.isCompleted.equals(false) &
                  t.isPrivate.equals(false) &
                  (t.dueDate.isNull() |
                      t.dueDate.isBiggerOrEqualValue(urgentCutoff)),
            ))
            .get();

    // 2. Exclusion rules learned from rejected proposals.
    final exclusionRules = await _db.select(_db.exclusionRules).get();

    // 3. Titles already proposed by this parent recently (dedup).
    final deduplicationCutoff = now.subtract(
      const Duration(days: _deduplicationDays),
    );
    final recentRows =
        await (_db.select(_db.partnerProposals)..where(
              (p) =>
                  p.fromParentId.equals(myParentId) &
                  p.receivedAt.isBiggerOrEqualValue(deduplicationCutoff),
            ))
            .get();
    final recentNormalized = recentRows
        .map((r) => _normalize(r.taskTitle))
        .toSet();

    // 4. Score and filter.
    final scored = <(PersonalTaskRow, int)>[];

    for (final row in rows) {
      final normalized = _normalize(row.title);

      if (recentNormalized.contains(normalized)) continue;

      final category = TaskCategory.values.firstWhere(
        (e) => e.name == row.category,
        orElse: () => TaskCategory.other,
      );
      int score = _categoryScores[category] ?? 30;

      // Keyword boost (at most once).
      for (final kw in _boostKeywords) {
        if (normalized.contains(kw)) {
          score += 20;
          break;
        }
      }

      // Exclusion penalties.
      for (final rule in exclusionRules) {
        if (normalized.contains(rule.pattern)) {
          score -= rule.penaltyScore;
        }
      }

      if (score >= _threshold) {
        scored.add((row, score));
      }
    }

    // 5. Sort by score descending, take top N.
    scored.sort((a, b) => b.$2.compareTo(a.$2));
    return scored.take(_maxPerCycle).map((e) => e.$1).toList();
  }

  /// Persists an exclusion rule derived from a rejected proposal's task title.
  ///
  /// Extracts the 1–2 most meaningful words (≥ 4 chars, stop-words excluded)
  /// and stores each as a separate pattern.
  Future<void> storeExclusionFromTitle(String taskTitle) async {
    final words = _normalize(taskTitle).split(RegExp(r'\s+'));
    final meaningful = words
        .where((w) => w.length >= 4 && !_stopWords.contains(w))
        .take(2)
        .toList();

    if (meaningful.isEmpty) {
      // Fall back to full normalized title if no meaningful words found.
      meaningful.add(_normalize(taskTitle));
    }

    for (final pattern in meaningful) {
      await _db
          .into(_db.exclusionRules)
          .insert(
            ExclusionRulesCompanion.insert(
              id: const Uuid().v4(),
              pattern: pattern,
              createdAt: DateTime.now().toUtc(),
            ),
          );
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  static String _normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9\s]'), '').trim();

  static const _stopWords = {
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
    'kan',
    'dat',
    'dit',
    'die',
    'deze',
    'haar',
    'mijn',
    'jouw',
    'ons',
    'hun',
  };
}
