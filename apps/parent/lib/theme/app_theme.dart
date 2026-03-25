import 'package:flutter/material.dart';

import '../todo/models/enums.dart';

// ---------------------------------------------------------------------------
// Brand palette constants used throughout the parent app.
// ---------------------------------------------------------------------------

const kColorTeal = Color(0xFF44BBA4);
const kColorGold = Color(0xFFE7BB41);
const kColorCharcoal = Color(0xFF393E41);
const kColorWarmGrey = Color(0xFFD3D0CB);
const kColorOffWhite = Color(0xFFE7E5DF);

// ---------------------------------------------------------------------------
// Priority colours + labels
// ---------------------------------------------------------------------------

Color priorityColor(TaskPriority p) => switch (p) {
  TaskPriority.high => Colors.redAccent,
  TaskPriority.medium => kColorGold,
  TaskPriority.low => Colors.blueAccent,
  TaskPriority.none => Colors.transparent,
};

String priorityLabel(TaskPriority p) => switch (p) {
  TaskPriority.high => '!!!',
  TaskPriority.medium => '!!',
  TaskPriority.low => '!',
  TaskPriority.none => '',
};

// ---------------------------------------------------------------------------
// Category icon
// ---------------------------------------------------------------------------

IconData categoryIcon(TaskCategory c) => switch (c) {
  TaskCategory.household => Icons.home_outlined,
  TaskCategory.health => Icons.favorite_border,
  TaskCategory.admin => Icons.description_outlined,
  TaskCategory.school => Icons.school_outlined,
  TaskCategory.finance => Icons.euro_outlined,
  TaskCategory.other => Icons.circle_outlined,
};

// ---------------------------------------------------------------------------
// Due date formatting helpers
// ---------------------------------------------------------------------------

String formatDueDate(DateTime due, {bool allDay = true}) {
  final now = DateTime.now();
  final d = due.toLocal();
  final diff = DateTime(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime(now.year, now.month, now.day)).inDays;

  final datePart = switch (diff) {
    0 => 'Vandaag',
    1 => 'Morgen',
    -1 => 'Gisteren',
    _ when diff < 0 => '${diff.abs()}d te laat',
    _ when diff < 7 => _weekday(d.weekday),
    _ => '${d.day} ${_month(d.month)}',
  };

  if (allDay) return datePart;
  final h = d.hour.toString().padLeft(2, '0');
  final m = d.minute.toString().padLeft(2, '0');
  return '$datePart $h:$m';
}

bool isOverdue(DateTime due) {
  final now = DateTime.now();
  final d = due.toLocal();
  return DateTime(
    d.year,
    d.month,
    d.day,
  ).isBefore(DateTime(now.year, now.month, now.day));
}

String _weekday(int w) => const [
  '',
  'Maandag',
  'Dinsdag',
  'Woensdag',
  'Donderdag',
  'Vrijdag',
  'Zaterdag',
  'Zondag',
][w];

String _month(int m) => const [
  '',
  'jan',
  'feb',
  'mrt',
  'apr',
  'mei',
  'jun',
  'jul',
  'aug',
  'sep',
  'okt',
  'nov',
  'dec',
][m];
