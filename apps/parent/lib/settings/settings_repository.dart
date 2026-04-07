import 'package:drift/drift.dart';

import '../db/app_database.dart';
import '../theme/app_themes.dart';

/// SettingsRepository — manages app settings persistence.
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository({required AppDatabase db}) : _db = db;

  /// Load the current theme preference from database.
  Future<AppTheme> loadTheme() async {
    final rows = await _db.select(_db.appSettings).get();
    if (rows.isEmpty) {
      // Initialize with default theme
      await _db
          .into(_db.appSettings)
          .insert(
            AppSettingsCompanion(
              key: const Value('default'),
              theme: const Value('light'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      return AppTheme.light;
    }

    final themeStr = rows.first.theme;
    return AppTheme.values.firstWhere(
      (t) => t.name == themeStr,
      orElse: () => AppTheme.light,
    );
  }

  /// Save theme preference to database.
  Future<void> saveTheme(AppTheme theme) async {
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value('default'),
            theme: Value(theme.name),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  /// Stream theme changes (if needed for reactive updates).
  Stream<AppTheme> watchTheme() {
    return _db.select(_db.appSettings).watchSingleOrNull().asyncMap((
      row,
    ) async {
      if (row == null) {
        await loadTheme(); // Initialize if missing
        return AppTheme.light;
      }
      return AppTheme.values.firstWhere(
        (t) => t.name == row.theme,
        orElse: () => AppTheme.light,
      );
    });
  }
}
