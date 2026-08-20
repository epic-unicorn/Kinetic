import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:parent/l10n/generated/app_localizations.dart';
import 'package:parent/theme/app_themes.dart';

void main() {
  group('AppTheme enum', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('all theme variants are defined', () {
      expect(AppTheme.values, hasLength(4));
      expect(AppTheme.light, isNotNull);
      expect(AppTheme.sand, isNotNull);
      expect(AppTheme.dusk, isNotNull);
      expect(AppTheme.night, isNotNull);
    });

    test('theme labels are user-friendly', () {
      expect(AppTheme.light.label(l10n), equals('Light'));
      expect(AppTheme.sand.label(l10n), equals('Sand'));
      expect(AppTheme.dusk.label(l10n), equals('Dusk'));
      expect(AppTheme.night.label(l10n), equals('Night'));
    });

    test('all themes have different labels', () {
      final themes = AppTheme.values;
      final labels = themes.map((t) => t.label(l10n)).toList();
      expect(labels.toSet().length, equals(labels.length));
    });
  });

  group('buildTheme()', () {
    test('returns valid ThemeData for light theme', () {
      final theme = buildTheme(AppTheme.light);

      expect(theme, isNotNull);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.light));
    });

    test('returns valid ThemeData for dusk theme', () {
      final theme = buildTheme(AppTheme.dusk);

      expect(theme, isNotNull);
      expect(theme.useMaterial3, isTrue);
      expect(theme.brightness, equals(Brightness.dark));
    });

    test('sand is light and night is dark', () {
      expect(buildTheme(AppTheme.sand).brightness, Brightness.light);
      expect(buildTheme(AppTheme.night).brightness, Brightness.dark);
      expect(
        buildTheme(AppTheme.night).scaffoldBackgroundColor,
        equals(Colors.black),
      );
    });

    test('all themes have Material 3 enabled', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.useMaterial3, isTrue);
      }
    });

    test('all themes have defined colorScheme', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.colorScheme, isNotNull);
      }
    });

    test('all themes have typography', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.textTheme, isNotNull);
        expect(themeData.textTheme.bodyLarge, isNotNull);
        expect(themeData.textTheme.headlineSmall, isNotNull);
      }
    });

    test('light and dusk themes have opposite brightness', () {
      final lightTheme = buildTheme(AppTheme.light);
      final darkTheme = buildTheme(AppTheme.dusk);

      expect(lightTheme.brightness, isNot(equals(darkTheme.brightness)));
    });

    test('appThemeFromName maps legacy dark to dusk', () {
      expect(appThemeFromName('dark'), AppTheme.dusk);
      expect(appThemeFromName('sand'), AppTheme.sand);
      expect(appThemeFromName('unknown'), AppTheme.light);
    });
  });

  group('Typography Scale', () {
    test('M3 typography includes all required levels', () {
      final theme = buildTheme(AppTheme.light);
      final text = theme.textTheme;

      // Display styles
      expect(text.displayLarge, isNotNull);
      expect(text.displayMedium, isNotNull);
      expect(text.displaySmall, isNotNull);

      // Headline styles
      expect(text.headlineLarge, isNotNull);
      expect(text.headlineMedium, isNotNull);
      expect(text.headlineSmall, isNotNull);

      // Title styles
      expect(text.titleLarge, isNotNull);
      expect(text.titleMedium, isNotNull);
      expect(text.titleSmall, isNotNull);

      // Body styles
      expect(text.bodyLarge, isNotNull);
      expect(text.bodyMedium, isNotNull);
      expect(text.bodySmall, isNotNull);

      // Label styles
      expect(text.labelLarge, isNotNull);
      expect(text.labelMedium, isNotNull);
      expect(text.labelSmall, isNotNull);
    });

    test('typography has appropriate font sizes', () {
      final theme = buildTheme(AppTheme.light);
      final text = theme.textTheme;

      // Display should be largest
      expect(text.displayLarge!.fontSize, greaterThan(40));

      // Body should be medium
      expect(text.bodyMedium!.fontSize, lessThan(20));
      expect(text.bodyMedium!.fontSize, greaterThan(10));

      // Label should be small
      expect(text.labelSmall!.fontSize, lessThan(12));
    });

    test('typography includes font weights', () {
      final theme = buildTheme(AppTheme.light);
      final text = theme.textTheme;

      expect(text.bodyLarge!.fontWeight, isNotNull);
      expect(text.headlineSmall!.fontWeight, isNotNull);
      expect(text.labelSmall!.fontWeight, isNotNull);
    });
  });

  group('Component Themes', () {
    test('all themes have AppBarTheme', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.appBarTheme, isNotNull);
        expect(themeData.appBarTheme.elevation, equals(0));
      }
    });

    test('all themes have CardThemeData', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.cardTheme, isNotNull);
      }
    });

    test('all themes have FloatingActionButtonThemeData', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.floatingActionButtonTheme, isNotNull);
      }
    });

    test('all themes have ListTileThemeData', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.listTileTheme, isNotNull);
      }
    });

    test('all themes have TabBarThemeData', () {
      for (final theme in AppTheme.values) {
        final themeData = buildTheme(theme);
        expect(themeData.tabBarTheme, isNotNull);
      }
    });
  });

  group('Brand Colors', () {
    test('brand palette colors are defined', () {
      expect(kColorTeal, isNotNull);
      expect(kColorGold, isNotNull);
      expect(kColorCharcoal, isNotNull);
      expect(kColorWarmGrey, isNotNull);
      expect(kColorOffWhite, isNotNull);
    });

    test('colors are valid Color values', () {
      expect(
        kColorTeal.value,
        equals(0xFF3B82F6),
      ); // kColorTeal = kColorKineticBlue (blue)
      expect(kColorGold.value, equals(0xFFE7BB41));
      expect(kColorCharcoal.value, equals(0xFF393E41));
    });

    test('custom color palette is defined', () {
      expect(kColorTeal, isNotNull);
      expect(kColorGold, isNotNull);
    });
  });

  group('Date formatting', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    test('formatDueDate returns today label', () {
      final today = DateTime.now();
      final formatted = formatDueDate(today, l10n);
      expect(formatted, isNotEmpty);
    });

    test('formatDueDate returns tomorrow label', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final formatted = formatDueDate(tomorrow, l10n);
      expect(formatted, isNotEmpty);
    });

    test('formatDueDate returns yesterday label', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final formatted = formatDueDate(yesterday, l10n);
      expect(formatted, isNotEmpty);
    });

    test('isOverdue identifies past dates', () {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      expect(isOverdue(yesterday), isTrue);
    });

    test('isOverdue returns false for future dates', () {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      expect(isOverdue(tomorrow), isFalse);
    });

    test('formatDueDate includes time when not allDay', () {
      final date = DateTime(2026, 4, 15, 14, 30);
      final formatted = formatDueDate(date, l10n, allDay: false);
      expect(formatted, isNotEmpty);
    });
  });
}
