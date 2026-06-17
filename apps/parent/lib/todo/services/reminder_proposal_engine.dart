import '../models/enums.dart';
import '../models/personal_task.dart';

/// A single smart reminder chip proposal.
class ReminderChipProposal {
  final String label;
  final DateTime at;
  final int score;
  final String? explanation;

  const ReminderChipProposal({
    required this.label,
    required this.at,
    required this.score,
    this.explanation,
  });
}

enum _ReminderProposalSource {
  habitTime,
  habitInterval,
  keyword,
  category,
  contextual,
  fallback,
}

class _ScoredCandidate {
  final DateTime at;
  final String label;
  final int score;
  final String? explanation;
  final _ReminderProposalSource source;

  const _ScoredCandidate({
    required this.at,
    required this.label,
    required this.score,
    this.explanation,
    required this.source,
  });
}

/// On-device heuristic engine that proposes contextual reminder chips.
class ReminderProposalEngine {
  static const _scoreHabitTime = 100;
  static const _scoreHabitInterval = 90;
  static const _scoreKeyword = 70;
  static const _scoreCategory = 50;
  static const _scoreContextual = 30;
  static const _scoreFallback = 10;

  static const _keywordRules = <String, ({int hour, int minute, String label})>{
    'school': (hour: 7, minute: 0, label: 'Morgen 07:00'),
    'huiswerk': (hour: 7, minute: 0, label: 'Morgen 07:00'),
    'sport': (hour: 18, minute: 0, label: 'Vanavond 18:00'),
    'training': (hour: 18, minute: 0, label: 'Vanavond 18:00'),
    'zwemmen': (hour: 18, minute: 0, label: 'Vanavond 18:00'),
    'boodschappen': (hour: 10, minute: 0, label: 'Za 10:00'),
    'supermarkt': (hour: 10, minute: 0, label: 'Za 10:00'),
    'belasting': (hour: 9, minute: 0, label: 'Over 3 dagen'),
    'deadline': (hour: 9, minute: 0, label: 'Over 3 dagen'),
    'verjaardag': (hour: 10, minute: 0, label: 'Over 3 dagen'),
    'cadeau': (hour: 10, minute: 0, label: 'Over 3 dagen'),
    'kapper': (hour: 9, minute: 0, label: 'Morgen 09:00'),
    'tandarts': (hour: 9, minute: 0, label: 'Morgen 09:00'),
    'afspraak': (hour: 9, minute: 0, label: 'Morgen 09:00'),
  };

  static const _dutchWeekdays = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];

  List<ReminderChipProposal> propose({
    required String title,
    TaskCategory? category,
    required List<PersonalTask> completedTasks,
    DateTime? now,
    int maxChips = 4,
  }) {
    final clock = (now ?? DateTime.now()).toLocal();
    final normalizedTitle = _normalize(title);

    if (normalizedTitle.isEmpty) {
      return _fallbackChips(clock, maxChips);
    }

    final candidates = <_ScoredCandidate>[
      ..._habitTimeCandidates(normalizedTitle, completedTasks, clock),
      ..._habitIntervalCandidates(normalizedTitle, completedTasks, clock),
      ..._keywordCandidates(normalizedTitle, clock),
      ..._categoryCandidates(category, clock),
      ..._contextualCandidates(clock),
      ..._fallbackCandidates(clock),
    ];

    candidates.sort((a, b) => b.score.compareTo(a.score));

    final picked = <ReminderChipProposal>[];
    for (final c in candidates) {
      if (c.at.isBefore(clock)) continue;
      if (picked.any((p) => p.at.difference(c.at).inMinutes.abs() < 30)) {
        continue;
      }
      picked.add(
        ReminderChipProposal(
          label: c.label,
          at: c.at,
          score: c.score,
          explanation: c.explanation,
        ),
      );
      if (picked.length >= maxChips) break;
    }

    if (picked.length < maxChips) {
      for (final fb in _fallbackChips(clock, maxChips)) {
        if (picked.any((p) => p.at.difference(fb.at).inMinutes.abs() < 30)) {
          continue;
        }
        picked.add(fb);
        if (picked.length >= maxChips) break;
      }
    }

    return picked;
  }

  List<ReminderChipProposal> _fallbackChips(DateTime clock, int maxChips) {
    return _fallbackCandidates(clock)
        .where((c) => c.at.isAfter(clock))
        .take(maxChips)
        .map(
          (c) => ReminderChipProposal(
            label: c.label,
            at: c.at,
            score: c.score,
            explanation: c.explanation,
          ),
        )
        .toList();
  }

  List<_ScoredCandidate> _habitTimeCandidates(
    String normalizedTitle,
    List<PersonalTask> completed,
    DateTime clock,
  ) {
    final slots = <String, int>{};
    for (final task in completed) {
      if (task.completedAt == null) continue;
      if (_normalize(task.title) != normalizedTitle) continue;
      final local = task.completedAt!.toLocal();
      final key = '${local.weekday}-${local.hour}';
      slots[key] = (slots[key] ?? 0) + 1;
    }
    final total = slots.values.fold<int>(0, (a, b) => a + b);
    if (total < 2) return [];

    final best = slots.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final parts = best.key.split('-');
    final weekday = int.parse(parts[0]);
    final hour = int.parse(parts[1]);
    final at = _nextWeekdayAt(clock, weekday, hour, 0);
    final count = best.value;
    return [
      _ScoredCandidate(
        at: at,
        label:
            '${_dutchWeekdays[weekday - 1]} ${hour.toString().padLeft(2, '0')}:00',
        score: _scoreHabitTime,
        explanation:
            'Je deed deze taak $count× op ${_dutchWeekdays[weekday - 1].toLowerCase()}ochtend',
        source: _ReminderProposalSource.habitTime,
      ),
    ];
  }

  List<_ScoredCandidate> _habitIntervalCandidates(
    String normalizedTitle,
    List<PersonalTask> completed,
    DateTime clock,
  ) {
    final times = <DateTime>[];
    for (final task in completed) {
      if (task.recurrenceRule != null) continue;
      if (task.completedAt == null) continue;
      if (_normalize(task.title) != normalizedTitle) continue;
      times.add(task.completedAt!);
    }
    if (times.length < 2) return [];

    times.sort();
    final median = _medianInterval(times);
    final lastDone = times.last;
    final daysSince = clock.toUtc().difference(lastDone).inDays;
    if (daysSince < median * 0.8) return [];

    final medianHour = _medianHour(times);
    final at = DateTime(
      clock.year,
      clock.month,
      clock.day,
      medianHour,
      0,
    ).add(Duration(days: median - daysSince));
    if (!at.isAfter(clock)) {
      return [];
    }

    final daysUntil = at.difference(clock).inDays;
    final label = daysUntil <= 1
        ? 'Morgen ${medianHour.toString().padLeft(2, '0')}:00'
        : 'Over $daysUntil dagen';

    return [
      _ScoredCandidate(
        at: at,
        label: label,
        score: _scoreHabitInterval,
        explanation:
            'Gemiddeld elke $median dagen, laatst $daysSince dagen geleden',
        source: _ReminderProposalSource.habitInterval,
      ),
    ];
  }

  List<_ScoredCandidate> _keywordCandidates(
    String normalizedTitle,
    DateTime clock,
  ) {
    final results = <_ScoredCandidate>[];
    for (final entry in _keywordRules.entries) {
      if (!normalizedTitle.contains(entry.key)) continue;
      final rule = entry.value;
      DateTime at;
      if (entry.key == 'boodschappen' || entry.key == 'supermarkt') {
        at = _nextWeekdayAt(clock, DateTime.saturday, rule.hour, rule.minute);
      } else if (entry.key == 'belasting' ||
          entry.key == 'deadline' ||
          entry.key == 'verjaardag' ||
          entry.key == 'cadeau') {
        at = DateTime(
          clock.year,
          clock.month,
          clock.day,
          rule.hour,
          rule.minute,
        ).add(const Duration(days: 3));
      } else if (entry.key == 'sport' ||
          entry.key == 'training' ||
          entry.key == 'zwemmen') {
        at = _eveningTodayOrTomorrow(clock, rule.hour, rule.minute);
      } else {
        at = _tomorrowAt(clock, rule.hour, rule.minute);
      }
      results.add(
        _ScoredCandidate(
          at: at,
          label: rule.label,
          score: _scoreKeyword,
          explanation: 'Past bij "${entry.key}" in de titel',
          source: _ReminderProposalSource.keyword,
        ),
      );
    }
    return results;
  }

  List<_ScoredCandidate> _categoryCandidates(
    TaskCategory? category,
    DateTime clock,
  ) {
    final cat = category ?? TaskCategory.other;
    final DateTime at;
    final String label;
    final String explanation;

    switch (cat) {
      case TaskCategory.school:
        at = _tomorrowAt(clock, 7, 0);
        label = 'Morgen 07:00';
        explanation = 'Schooltaken plan je meestal in de ochtend';
      case TaskCategory.household:
        at = _nextWeekdayAt(clock, DateTime.saturday, 9, 0);
        label = 'Za 09:00';
        explanation = 'Huishoudtaken plan je vaak in het weekend';
      case TaskCategory.health:
        at = _tomorrowAt(clock, 8, 0);
        label = 'Morgen 08:00';
        explanation = 'Gezondheidstaken herinner je vaak in de ochtend';
      case TaskCategory.finance:
      case TaskCategory.admin:
        at = _tomorrowAt(clock, 9, 0);
        label = 'Morgen 09:00';
        explanation = 'Administratieve taken plan je vaak overdag';
      case TaskCategory.other:
        at = _tomorrowAt(clock, 9, 0);
        label = 'Morgen 09:00';
        explanation = 'Standaard ochtendherinnering';
    }

    return [
      _ScoredCandidate(
        at: at,
        label: label,
        score: _scoreCategory,
        explanation: explanation,
        source: _ReminderProposalSource.category,
      ),
    ];
  }

  List<_ScoredCandidate> _contextualCandidates(DateTime clock) {
    final results = <_ScoredCandidate>[];
    if (clock.hour < 20) {
      results.add(
        _ScoredCandidate(
          at: DateTime(clock.year, clock.month, clock.day, 20, 0),
          label: 'Vanavond 20:00',
          score: _scoreContextual,
          explanation: 'Snelle avondherinnering',
          source: _ReminderProposalSource.contextual,
        ),
      );
    }
    results.add(
      _ScoredCandidate(
        at: _tomorrowAt(clock, 9, 0),
        label: 'Morgen 09:00',
        score: _scoreContextual,
        explanation: 'Standaard ochtendherinnering',
        source: _ReminderProposalSource.contextual,
      ),
    );
    if (clock.hour < 20) {
      results.add(
        _ScoredCandidate(
          at: _tomorrowAt(clock, 20, 0),
          label: 'Morgen 20:00',
          score: _scoreContextual - 1,
          explanation: 'Herinnering morgenavond',
          source: _ReminderProposalSource.contextual,
        ),
      );
    }
    return results;
  }

  List<_ScoredCandidate> _fallbackCandidates(DateTime clock) {
    return [
      _ScoredCandidate(
        at: clock.add(const Duration(hours: 1)),
        label: 'Over 1 uur',
        score: _scoreFallback,
        explanation: 'Snelle herinnering',
        source: _ReminderProposalSource.fallback,
      ),
      ..._contextualCandidates(clock),
    ];
  }

  DateTime _tomorrowAt(DateTime clock, int hour, int minute) {
    final tomorrow = clock.add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
  }

  DateTime _eveningTodayOrTomorrow(DateTime clock, int hour, int minute) {
    final tonight = DateTime(clock.year, clock.month, clock.day, hour, minute);
    if (tonight.isAfter(clock)) return tonight;
    return _tomorrowAt(clock, hour, minute);
  }

  DateTime _nextWeekdayAt(
    DateTime clock,
    int weekday,
    int hour,
    int minute,
  ) {
    var candidate = DateTime(clock.year, clock.month, clock.day, hour, minute);
    while (candidate.weekday != weekday || !candidate.isAfter(clock)) {
      candidate = candidate.add(const Duration(days: 1));
    }
    return candidate;
  }

  int _medianInterval(List<DateTime> sorted) {
    final gaps = <int>[];
    for (var i = 1; i < sorted.length; i++) {
      gaps.add(sorted[i].difference(sorted[i - 1]).inDays);
    }
    gaps.sort();
    final mid = gaps.length ~/ 2;
    return gaps.length.isOdd ? gaps[mid] : ((gaps[mid - 1] + gaps[mid]) ~/ 2);
  }

  int _medianHour(List<DateTime> times) {
    final hours = times.map((t) => t.toLocal().hour).toList()..sort();
    return hours[hours.length ~/ 2];
  }

  String _normalize(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]'), ' ')
      .trim();
}
