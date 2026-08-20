import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../theme/app_themes.dart';

/// SettingsRepository — manages app settings persistence.
class SettingsRepository {
  final AppDatabase _db;

  SettingsRepository({required AppDatabase db}) : _db = db;

  static const supportedLocales = [Locale('en'), Locale('nl')];

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
              localeCode: const Value('en'),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
      return AppTheme.light;
    }

    return appThemeFromName(rows.first.theme);
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

  /// Load UI locale (`en` / `nl` only). Defaults to English.
  Future<Locale> loadLocale() async {
    final rows = await _db.select(_db.appSettings).get();
    if (rows.isEmpty) {
      await loadTheme();
      return const Locale('en');
    }
    return _localeFromCode(rows.first.localeCode);
  }

  /// Persist UI locale (`en` / `nl` only).
  Future<void> saveLocale(Locale locale) async {
    final code = locale.languageCode == 'nl' ? 'nl' : 'en';
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value('default'),
            localeCode: Value(code),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  static Locale _localeFromCode(String? code) {
    if (code == 'nl') return const Locale('nl');
    return const Locale('en');
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
      return appThemeFromName(row.theme);
    });
  }

  // ── Category order persistence ─────────────────────────────────────────────

  Future<List<String?>> loadTaskCategoryOrder() async {
    final rows = await _db.select(_db.appSettings).get();
    if (rows.isEmpty || rows.first.taskCategoryOrder == null) return [];
    try {
      final list = jsonDecode(rows.first.taskCategoryOrder!) as List<dynamic>;
      return list.map((e) => e as String?).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveTaskCategoryOrder(List<String?> order) async {
    final json = jsonEncode(order);
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value('default'),
            taskCategoryOrder: Value(json),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<List<String?>> loadNoteCategoryOrder() async {
    final rows = await _db.select(_db.appSettings).get();
    if (rows.isEmpty || rows.first.noteCategoryOrder == null) return [];
    try {
      final list = jsonDecode(rows.first.noteCategoryOrder!) as List<dynamic>;
      return list.map((e) => e as String?).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveNoteCategoryOrder(List<String?> order) async {
    final json = jsonEncode(order);
    await _db
        .into(_db.appSettings)
        .insertOnConflictUpdate(
          AppSettingsCompanion(
            key: const Value('default'),
            noteCategoryOrder: Value(json),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }
}
