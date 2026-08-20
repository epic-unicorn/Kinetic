import 'package:flutter/material.dart';

import '../todo/models/enums.dart';

// ---------------------------------------------------------------------------
// Brand Palette
// ---------------------------------------------------------------------------

const kColorKineticBlue = Color(0xFF3B82F6); // Primary blue from app icon
const kColorTeal = kColorKineticBlue; // Updated to match new app icon theme
const kColorGold = Color(0xFFE7BB41);
const kColorCharcoal = Color(0xFF393E41);
const kColorWarmGrey = Color(0xFFD3D0CB);
const kColorOffWhite = Color(0xFFE7E5DF);

// Custom theme colors removed

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
  TaskPriority.high => 'H',
  TaskPriority.medium => 'M',
  TaskPriority.low => 'L',
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

bool isOverdue(DateTime due, {bool isAllDay = false}) {
  final now = DateTime.now();
  final local = due.toLocal();
  // For all-day tasks the deadline is end-of-day (23:59:59), not midnight.
  final effective = isAllDay
      ? DateTime(local.year, local.month, local.day, 23, 59, 59)
      : local;
  return effective.isBefore(now);
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

// ---------------------------------------------------------------------------
// Theme definitions
// ---------------------------------------------------------------------------

enum AppTheme { light, sand, dusk, night }

extension AppThemeLabel on AppTheme {
  String get label => switch (this) {
    AppTheme.light => 'Licht',
    AppTheme.sand => 'Zand',
    AppTheme.dusk => 'Schemer',
    AppTheme.night => 'Nacht',
  };

  String get description => switch (this) {
    AppTheme.light => 'Helder blauw',
    AppTheme.sand => 'Warm papier',
    AppTheme.dusk => 'Blauw-grijs donker',
    AppTheme.night => 'OLED zwart',
  };
}

/// Maps a persisted theme name to [AppTheme], including the pre-0.3 `dark` id.
AppTheme appThemeFromName(String? name) {
  if (name == 'dark') return AppTheme.dusk;
  return AppTheme.values.firstWhere(
    (t) => t.name == name,
    orElse: () => AppTheme.light,
  );
}

ThemeData buildTheme(AppTheme theme) {
  return switch (theme) {
    AppTheme.light => _themeFromScheme(
      ColorScheme.fromSeed(
        seedColor: kColorKineticBlue,
        brightness: Brightness.light,
      ),
    ),
    AppTheme.sand => _themeFromScheme(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFC4783A),
        brightness: Brightness.light,
        surface: const Color(0xFFF7F1E6),
        surfaceContainerLow: const Color(0xFFF1E9DA),
        surfaceContainerHigh: const Color(0xFFE8DCC8),
      ),
      scaffold: const Color(0xFFF7F1E6),
    ),
    AppTheme.dusk => _themeFromScheme(
      ColorScheme.fromSeed(
        seedColor: kColorKineticBlue,
        brightness: Brightness.dark,
        surface: const Color(0xFF1E2030),
        surfaceContainerLow: const Color(0xFF252839),
        surfaceContainerHigh: const Color(0xFF2C3050),
      ),
      scaffold: const Color(0xFF1E2030),
    ),
    AppTheme.night => _themeFromScheme(
      ColorScheme.fromSeed(
        seedColor: kColorKineticBlue,
        brightness: Brightness.dark,
        surface: const Color(0xFF0A0A0A),
        surfaceContainerLow: const Color(0xFF141414),
        surfaceContainerHigh: const Color(0xFF1C1C1C),
      ),
      scaffold: Colors.black,
    ),
  };
}

ThemeData _themeFromScheme(ColorScheme colorScheme, {Color? scaffold}) {
  final background = scaffold ?? colorScheme.surface;
  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    brightness: colorScheme.brightness,
    scaffoldBackgroundColor: background,
    appBarTheme: AppBarTheme(
      backgroundColor: background,
      foregroundColor: colorScheme.onSurface,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    listTileTheme: ListTileThemeData(
      tileColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: _buildTextTheme(colorScheme.onSurface),
    tabBarTheme: TabBarThemeData(
      labelColor: colorScheme.primary,
      unselectedLabelColor: colorScheme.onSurfaceVariant,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(color: colorScheme.primary, width: 3),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// M3 Typography Scale
// ---------------------------------------------------------------------------

TextTheme _buildTextTheme(Color textColor) {
  return TextTheme(
    // Display styles
    displayLarge: TextStyle(
      fontSize: 57,
      fontWeight: FontWeight.w400,
      height: 1.12,
      color: textColor,
      letterSpacing: -0.25,
    ),
    displayMedium: TextStyle(
      fontSize: 45,
      fontWeight: FontWeight.w400,
      height: 1.16,
      color: textColor,
      letterSpacing: 0,
    ),
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w400,
      height: 1.22,
      color: textColor,
      letterSpacing: 0,
    ),
    // Headline styles
    headlineLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w400,
      height: 1.25,
      color: textColor,
      letterSpacing: 0,
    ),
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w400,
      height: 1.29,
      color: textColor,
      letterSpacing: 0,
    ),
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w400,
      height: 1.33,
      color: textColor,
      letterSpacing: 0,
    ),
    // Title styles
    titleLarge: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w500,
      height: 1.27,
      color: textColor,
      letterSpacing: 0,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: textColor,
      letterSpacing: 0.15,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.43,
      color: textColor,
      letterSpacing: 0.1,
    ),
    // Body styles
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: textColor,
      letterSpacing: 0.15,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.43,
      color: textColor,
      letterSpacing: 0.25,
    ),
    bodySmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      height: 1.33,
      color: textColor,
      letterSpacing: 0.4,
    ),
    // Label styles
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.43,
      color: textColor,
      letterSpacing: 0.1,
    ),
    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      height: 1.33,
      color: textColor,
      letterSpacing: 0.5,
    ),
    labelSmall: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: textColor,
      letterSpacing: 0.5,
    ),
  );
}
