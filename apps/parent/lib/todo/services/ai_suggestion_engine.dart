import 'package:drift/drift.dart';

import '../../db/app_database.dart';
import '../../partner/services/partner_proposal_repository.dart';
import '../../todo/models/enums.dart';
import '../../todo/services/todo_repository.dart';
import 'ai_suggestion_repository.dart';
import '../models/ai_suggestion.dart';

/// Heuristic-based suggestion engine.
///
/// Call [runIfDue] on app resume and on first init. The engine throttles itself
/// to run at most once per day (self path) / once per day (partner path).
class AiSuggestionEngine {
  final AppDatabase _db;
  final AiSuggestionRepository _suggestionRepo;
  final TodoRepository _todoRepo;
  final PartnerProposalRepository? _proposalRepo;

  /// The current user's parent-id (used for auto partner proposals).
  final String? myParentId;

  static const _maxPendingSelf = 3;
  static const _maxAutoPartnerPerDay = 2;

  AiSuggestionEngine({
    required AppDatabase db,
    required AiSuggestionRepository suggestionRepo,
    required TodoRepository todoRepo,
    PartnerProposalRepository? proposalRepo,
    this.myParentId,
  }) : _db = db,
       _suggestionRepo = suggestionRepo,
       _todoRepo = todoRepo,
       _proposalRepo = proposalRepo;

  // ---------------------------------------------------------------------------
  // Entry point
  // ---------------------------------------------------------------------------

  Future<void> runIfDue() async {
    final settings = await _loadSettings();
    final now = DateTime.now().toUtc();

    final selfDue = _isDue(settings?.lastSuggestionRunAt, now);
    final partnerDue = _isDue(settings?.lastPartnerSuggestionRunAt, now);

    if (!selfDue && !partnerDue) return;

    final completedTasks = await _todoRepo.watchCompletedTasks().first;
    final openTasks = await _todoRepo.watchOpenTasks().first;
    final openTitlesNorm =
        openTasks.map((t) => _normalize(t.title)).toSet();

    if (selfDue) {
      await _runHabitDetector(completedTasks, openTitlesNorm);
      await _runSeasonalDetector(completedTasks, openTitlesNorm);
      await _updateLastRun(selfPath: true);
    }

    if (partnerDue && _proposalRepo != null && myParentId != null) {
      await _runPartnerComplementDetector();
      await _runLoadBalanceDetector(openTasks);
      await _updateLastRun(selfPath: false);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 1 — Habit (→ self)
  // ---------------------------------------------------------------------------

  Future<void> _runHabitDetector(
    List<dynamic> completed,
    Set<String> openTitlesNorm,
  ) async {
    if (await _suggestionRepo.countPending() >= _maxPendingSelf) return;

    // Group completed non-recurring tasks by normalized title.
    final groups = <String, List<DateTime>>{};
    for (final task in completed) {
      if (task.recurrenceRule != null) continue;
      if (task.completedAt == null) continue;
      final key = _normalize(task.title);
      groups.putIfAbsent(key, () => []).add(task.completedAt!);
    }

    for (final entry in groups.entries) {
      if (await _suggestionRepo.countPending() >= _maxPendingSelf) break;
      final times = entry.value..sort();
      if (times.length < 2) continue;

      final medianInterval = _medianInterval(times);
      final lastDone = times.last;
      final daysSince = DateTime.now().toUtc().difference(lastDone).inDays;

      if (daysSince < medianInterval * 0.8) continue;
      if (openTitlesNorm.contains(entry.key)) continue;

      final original = completed.firstWhere(
        (t) => _normalize(t.title) == entry.key,
      );
      final suggested = AiSuggestion.create(
        title: original.title,
        notes: original.notes,
        priority: original.priority.index,
        category: original.category.name,
        suggestedDueDate:
            lastDone.add(Duration(days: medianInterval.round())).toLocal(),
        reason: SuggestionReason.habit,
      );
      await _suggestionRepo.upsertSuggestion(suggested);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 2 — Partner complement (→ partner, auto)
  // ---------------------------------------------------------------------------

  static const _complementMap = <String, String>{
    'vakantie': 'Vakantie packing list maken',
    'holiday': 'Vakantie packing list maken',
    'sport': 'Sportkleding wassen',
    'school': 'Schooltas controleren',
    'boodschappen': 'Boodschappenlijst bijwerken',
    'shopping': 'Boodschappenlijst bijwerken',
    'koken': 'Maaltijdplan voor de week',
    'cooking': 'Maaltijdplan voor de week',
  };

  Future<void> _runPartnerComplementDetector() async {
    final proposalRepo = _proposalRepo;
    if (proposalRepo == null) return;
    final parentId = myParentId;
    if (parentId == null) return;

    final accepted = await proposalRepo.watchAccepted().first;
    int sent = 0;

    for (final proposal in accepted) {
      if (sent >= _maxAutoPartnerPerDay) break;
      final titleNorm = _normalize(proposal.taskTitle);

      for (final kv in _complementMap.entries) {
        if (!titleNorm.contains(kv.key)) continue;
        final complement = kv.value;
        final alreadySent = await proposalRepo.hasRecentOutgoing(
          complement,
          parentId,
        );
        if (alreadySent) break;
        await proposalRepo.createManualProposal(
          myParentId: parentId,
          taskTitle: complement,
          taskPriority: TaskPriority.none,
        );
        sent++;
        break;
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 3 — Seasonal (→ self)
  // ---------------------------------------------------------------------------

  Future<void> _runSeasonalDetector(
    List<dynamic> completed,
    Set<String> openTitlesNorm,
  ) async {
    if (await _suggestionRepo.countPending() >= _maxPendingSelf) return;

    final currentMonth = DateTime.now().month;
    final currentYear = DateTime.now().year;

    // Map normalized title → set of (year, month) combos where it was completed.
    final history = <String, List<DateTime>>{};
    for (final task in completed) {
      if (task.completedAt == null) continue;
      final key = _normalize(task.title);
      history.putIfAbsent(key, () => []).add(task.completedAt!);
    }

    for (final entry in history.entries) {
      if (await _suggestionRepo.countPending() >= _maxPendingSelf) break;
      if (openTitlesNorm.contains(entry.key)) continue;

      final priorYearMatch = entry.value.any(
        (dt) =>
            dt.month == currentMonth && dt.year < currentYear,
      );
      if (!priorYearMatch) continue;

      final original = completed.firstWhere(
        (t) => _normalize(t.title) == entry.key,
      );
      final suggested = AiSuggestion.create(
        title: original.title,
        notes: original.notes,
        priority: original.priority.index,
        category: original.category.name,
        reason: SuggestionReason.seasonal,
      );
      await _suggestionRepo.upsertSuggestion(suggested);
    }
  }

  // ---------------------------------------------------------------------------
  // Detector 4 — Load balance (→ partner, auto)
  // ---------------------------------------------------------------------------

  Future<void> _runLoadBalanceDetector(List<dynamic> openTasks) async {
    final proposalRepo = _proposalRepo;
    if (proposalRepo == null) return;
    final parentId = myParentId;
    if (parentId == null) return;

    final byCategory = <String, List<dynamic>>{};
    for (final task in openTasks) {
      if (task.isPrivate) continue;
      final cat = task.category.name;
      byCategory.putIfAbsent(cat, () => []).add(task);
    }

    int sent = 0;
    for (final entry in byCategory.entries) {
      if (sent >= _maxAutoPartnerPerDay) break;
      if (entry.value.length < 3) continue;

      // Pick the most overdue / oldest candidate.
      final candidates = List<dynamic>.from(entry.value)
        ..sort(
          (a, b) => (a.dueDate ?? a.createdAt).compareTo(
            b.dueDate ?? b.createdAt,
          ),
        );
      final candidate = candidates.first;
      final alreadySent = await proposalRepo.hasRecentOutgoing(
        candidate.title,
        parentId,
      );
      if (alreadySent) continue;

      await proposalRepo.createManualProposal(
        myParentId: parentId,
        taskTitle: candidate.title,
        taskNotes: candidate.notes,
        taskPriority: candidate.priority,
        taskDueDate: candidate.dueDate,
      );
      sent++;
    }
  }

  // ---------------------------------------------------------------------------
  // Throttle helpers
  // ---------------------------------------------------------------------------

  bool _isDue(DateTime? lastRun, DateTime now) {
    if (lastRun == null) return true;
    return now.difference(lastRun).inHours >= 24;
  }

  Future<AppSettingsRow?> _loadSettings() async {
    final rows = await _db.select(_db.appSettings).get();
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> _updateLastRun({required bool selfPath}) async {
    final now = DateTime.now().toUtc();
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

  // ---------------------------------------------------------------------------
  // Utilities
  // ---------------------------------------------------------------------------

  String _normalize(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]'), ' ').trim();

  int _medianInterval(List<DateTime> sorted) {
    final gaps = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      gaps.add(sorted[i].difference(sorted[i - 1]).inDays);
    }
    gaps.sort();
    final mid = gaps.length ~/ 2;
    return gaps.length.isOdd ? gaps[mid] : ((gaps[mid - 1] + gaps[mid]) ~/ 2);
  }
}
