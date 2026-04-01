import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids/db/app_database.dart';
import 'package:kids/main.dart';
import 'package:kids/task/screens/kids_home_screen.dart';

void main() {
  group('KineticKidsApp', () {
    testWidgets('app builds without error', (WidgetTester tester) async {
      final appDb = AppDatabase();
      await tester.pumpWidget(KineticKidsApp(appDb: appDb));
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('uses Material 3 theme', (WidgetTester tester) async {
      final appDb = AppDatabase();
      await tester.pumpWidget(KineticKidsApp(appDb: appDb));

      final materialApp =
          find.byType(MaterialApp).evaluate().first.widget as MaterialApp;
      expect(materialApp.theme?.useMaterial3, isTrue);
    });

    testWidgets('renders home screen', (WidgetTester tester) async {
      final appDb = AppDatabase();
      await tester.pumpWidget(KineticKidsApp(appDb: appDb));

      expect(find.byType(KidsHomeScreen), findsOneWidget);
    });

    testWidgets('home screen has app bar', (WidgetTester tester) async {
      final appDb = AppDatabase();
      await tester.pumpWidget(
        MaterialApp(
          home: KidsHomeScreen(appDb: appDb),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE7BB41),
            ),
          ),
        ),
      );

      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('home screen displays title', (WidgetTester tester) async {
      final appDb = AppDatabase();
      await tester.pumpWidget(
        MaterialApp(
          home: KidsHomeScreen(appDb: appDb),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE7BB41),
            ),
          ),
        ),
      );

      expect(find.byType(Text), findsWidgets);
    });
  });
}
