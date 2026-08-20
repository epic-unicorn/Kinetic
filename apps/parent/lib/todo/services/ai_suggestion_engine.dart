import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../partner/services/partner_proposal_repository.dart';
import '../../todo/models/personal_task.dart';
import '../../todo/services/todo_repository.dart';
import '../models/ai_suggestion.dart';
import '../reminder_time.dart';
import 'ai_suggestion_repository.dart';
import 'suggestion_heuristics.dart';

/// Heuristic-based suggestion engine.
///
/// Call [runIfDue] on app resume and on first init. A run that creates at
/// least one suggestion is throttled for 24 hours; an empty run is not, so
/// new tasks can surface hints on the next open.
class AiSuggestionEngine {
  final AppDatabase _db;
  final AiSuggestionRepository _suggestionRepo;
  final TodoRepository _todoRepo;
  final PartnerProposalRepository? _proposalRepo;
  final String? myParentId;
  final DateTime Function() _now;

  static const _maxPendingSelf = 3;
  static const _maxPendingPartner = 3;
  static const _staleAfterDays = 7;
  static const _singleHabitSilenceDays = 14;
  static const _privacyBudget = Duration(days: 14);

  AiSuggestionEngine({
    required AppDatabase db,
    required AiSuggestionRepository suggestionRepo,
    required TodoRepository todoRepo,
    PartnerProposalRepository? proposalRepo,
    this.myParentId,
    DateTime Function()? now,
  }) : _db = db,
       _suggestionRepo = suggestionRepo,
       _todoRepo = todoRepo,
       _proposalRepo = proposalRepo,
       _now = now ?? DateTime.now;

  DateTime get _nowUtc => _now().toUtc();

  Future<void> runIfDue() async {
    final settings = await _loadSettings();
    final now = _nowUtc;

    final selfDue = _isDue(settings?.lastSuggestionRunAt, now);
    final partnerDue = _isDue(settings?.lastPartnerSuggestionRunAt, now);

    if (!selfDue && !partnerDue) return;

    final completedTasks = await _todoRepo.watchCompletedTasks().first;
    final openTasks = await _todoRepo.watchOpenTasks().first;
    final openTitlesNorm = openTasks
        .map((t) => normalizeSuggestionText(t.title))
        .toSet();

    if (selfDue) {
      final before = await _suggestionRepo.countPendingSelf();
      await _runHabitDetector(completedTasks, openTitlesNorm);
      await _runSeasonalDetector(completedTasks, openTitlesNorm);
      await _runCalendarDetector(openTitlesNorm);
      await _runStaleDetector(openTasks);
      final after = await _suggestionRepo.countPendingSelf();
      if (after > before) await _updateLastRun(selfPath: true);
    }

    if (partnerDue && _proposalRepo != null) {
      final before = await _suggestionRepo.countPendingPartner();
      await _runPartnerComplementDetector(openTasks);
      await _runLoadBalanceDetector(openTasks);
      final after = await _suggestionRepo.countPendingPartner();
      if (after > before) await _updateLastRun(selfPath: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 1 — Habit (→ self)
  // ---------------------------------------------------------------------------

  Future<void> _runHabitDetector(
    List<PersonalTask> completed,
    Set<String> openTitlesNorm,
  ) async {
    if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) return;

    final groups = <String, List<PersonalTask>>{};
    for (final task in completed) {
      if (task.recurrenceRule != null) continue;
      if (task.completedAt == null) continue;
      final key = normalizeSuggestionText(task.title);
      groups.putIfAbsent(key, () => []).add(task);
    }

    for (final entry in groups.entries) {
      if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) break;
      if (openTitlesNorm.contains(entry.key)) continue;

      final times = entry.value.map((t) => t.completedAt!).toList()..sort();
      final lastDone = times.last;
      final daysSince = _nowUtc.difference(lastDone).inDays;
      final original = entry.value.last;

      final repeatDue =
          times.length >= 2 && daysSince >= _medianInterval(times) * 0.8;
      final singleKeywordDue =
          times.length == 1 &&
          isStrongHabitTitle(original.title) &&
          daysSince >= _singleHabitSilenceDays;

      if (!repeatDue && !singleKeywordDue) continue;

      final median = times.length >= 2 ? _medianInterval(times) : daysSince;
      final suggested = AiSuggestion.create(
        title: original.title,
        notes: original.notes,
        priority: original.priority.index,
        category: original.category.name,
        suggestedDueDate: lastDone
            .add(Duration(days: median.round()))
            .toLocal(),
        reason: SuggestionReason.habit,
        explanation: times.length >= 2
            ? 'Je deed "${original.title}" gemiddeld elke $median dagen. '
                  'Laatste keer: $daysSince dagen geleden.'
            : 'Je deed "${original.title}" $daysSince dagen geleden. '
                  'Opnieuw inplannen?',
      );
      await _suggestionRepo.upsertSuggestion(suggested);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 2 — Partner complement from the user's own tasks (→ partner)
  // ---------------------------------------------------------------------------

  Future<void> _runPartnerComplementDetector(
    List<PersonalTask> openTasks,
  ) async {
    if (await _suggestionRepo.countPendingPartner() >= _maxPendingPartner) {
      return;
    }

    final seenFamilies = <String>{};
    for (final task in openTasks) {
      if (await _suggestionRepo.countPendingPartner() >= _maxPendingPartner) {
        break;
      }
      final hint = matchPartnerHint(title: task.title, notes: task.notes);
      if (hint == null) continue;
      if (!seenFamilies.add(hint.familyId)) continue;
      if (await _suggestionRepo.hasRecentWithTitle(
        hint.partnerTitle,
        within: _privacyBudget,
      )) {
        continue;
      }

      final suggested = AiSuggestion.create(
        title: hint.partnerTitle,
        category: hint.categories.isEmpty
            ? task.category.name
            : hint.categories.first.name,
        reason: SuggestionReason.partnerComplement,
        explanation: hint.explanation,
      );
      await _suggestionRepo.upsertSuggestion(suggested);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 3 — Seasonal history (→ self)
  // ---------------------------------------------------------------------------

  Future<void> _runSeasonalDetector(
    List<PersonalTask> completed,
    Set<String> openTitlesNorm,
  ) async {
    if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) return;

    final currentMonth = _now().month;
    final currentYear = _now().year;

    final history = <String, List<DateTime>>{};
    for (final task in completed) {
      if (task.completedAt == null) continue;
      final key = normalizeSuggestionText(task.title);
      history.putIfAbsent(key, () => []).add(task.completedAt!);
    }

    for (final entry in history.entries) {
      if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) break;
      if (openTitlesNorm.contains(entry.key)) continue;

      final priorYearMatch = entry.value.any(
        (dt) => dt.month == currentMonth && dt.year < currentYear,
      );
      if (!priorYearMatch) continue;

      final original = completed.firstWhere(
        (t) => normalizeSuggestionText(t.title) == entry.key,
      );
      final monthName = _monthName(currentMonth);
      final suggested = AiSuggestion.create(
        title: original.title,
        notes: original.notes,
        priority: original.priority.index,
        category: original.category.name,
        reason: SuggestionReason.seasonal,
        explanation:
            'Je voltooide "${original.title}" in $monthName vorig jaar.',
      );
      await _suggestionRepo.upsertSuggestion(suggested);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 3b — Calendar keywords (→ self, year 1)
  // ---------------------------------------------------------------------------

  Future<void> _runCalendarDetector(Set<String> openTitlesNorm) async {
    if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) return;

    final corpus = openTitlesNorm.join(' ');
    for (final prompt in calendarPromptsForMonth(_now().month)) {
      if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) break;
      if (containsAnyKeyword(corpus, prompt.skipIfTitleContains)) continue;
      if (await _suggestionRepo.hasPendingWithTitle(prompt.title)) continue;

      await _suggestionRepo.upsertSuggestion(
        AiSuggestion.create(
          title: prompt.title,
          reason: SuggestionReason.calendar,
          explanation: prompt.explanation,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 3c — Stale open tasks (→ self)
  // ---------------------------------------------------------------------------

  Future<void> _runStaleDetector(List<PersonalTask> openTasks) async {
    if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) return;

    for (final task in openTasks) {
      if (await _suggestionRepo.countPendingSelf() >= _maxPendingSelf) break;
      if (task.dueDate != null || task.remindAt != null) continue;
      final ageDays = _nowUtc.difference(task.createdAt).inDays;
      if (ageDays < _staleAfterDays) continue;
      if (await _suggestionRepo.hasPendingWithTitle(task.title)) continue;

      await _suggestionRepo.upsertSuggestion(
        AiSuggestion.create(
          title: task.title,
          notes: task.notes,
          priority: task.priority.index,
          category: task.category.name,
          suggestedDueDate: suggestedReminderAt(_now()),
          reason: SuggestionReason.stale,
          explanation:
              '"${task.title}" staat al $ageDays dagen open zonder herinnering.',
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 4 — Load balance (→ partner, generic payload)
  // ---------------------------------------------------------------------------

  Future<void> _runLoadBalanceDetector(List<PersonalTask> openTasks) async {
    if (await _suggestionRepo.countPendingPartner() >= _maxPendingPartner) {
      return;
    }

    final byCategory = <String, List<PersonalTask>>{};
    for (final task in openTasks) {
      byCategory.putIfAbsent(task.category.name, () => []).add(task);
    }

    for (final entry in byCategory.entries) {
      if (await _suggestionRepo.countPendingPartner() >= _maxPendingPartner) {
        break;
      }
      final threshold = entry.key == 'other' ? 5 : 3;
      if (entry.value.length < threshold) continue;

      final title = loadBalanceTitle(entry.key);
      if (await _suggestionRepo.hasRecentWithTitle(
        title,
        within: _privacyBudget,
      )) {
        continue;
      }

      final suggested = AiSuggestion.create(
        title: title,
        category: entry.key,
        reason: SuggestionReason.loadBalance,
        explanation:
            'Je hebt ${entry.value.length} open taken in '
            '${categoryLabelNl(entry.key)}. Het voorstel is bewust algemeen.',
      );
      await _suggestionRepo.upsertSuggestion(suggested);
    }
  }

  bool _isDue(DateTime? lastRun, DateTime now) {
    if (lastRun == null) return true;
    return now.difference(lastRun).inHours >= 24;
  }

  Future<AppSettingsRow?> _loadSettings() async {
    final rows = await _db.select(_db.appSettings).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _updateLastRun({required bool selfPath}) async {
    final now = _nowUtc;
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          selfPath
              ? AppSettingsCompanion(
                  key: const Value('default'),
                  lastSuggestionRunAt: Value(now),
                  updatedAt: Value(now),
                )
              : AppSettingsCompanion(
                  key: const Value('default'),
                  lastPartnerSuggestionRunAt: Value(now),
                  updatedAt: Value(now),
                ),
        );
  }

  int _medianInterval(List<DateTime> sorted) {
    final gaps = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      gaps.add(sorted[i].difference(sorted[i - 1]).inDays);
    }
    gaps.sort();
    if (gaps.isEmpty) return 0;
    final mid = gaps.length ~/ 2;
    return gaps.length.isOdd ? gaps[mid] : ((gaps[mid - 1] + gaps[mid]) ~/ 2);
  }

  String _monthName(int month) => const [
    'januari',
    'februari',
    'maart',
    'april',
    'mei',
    'juni',
    'juli',
    'augustus',
    'september',
    'oktober',
    'november',
    'december',
  ][month - 1];
}
