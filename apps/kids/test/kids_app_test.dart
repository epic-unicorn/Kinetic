import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids/main.dart';

void main() {
  group('KineticKidsApp', () {
    testWidgets('app builds without error', (WidgetTester tester) async {
      await tester.pumpWidget(const KineticKidsApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('uses Material 3 theme', (WidgetTester tester) async {
      await tester.pumpWidget(const KineticKidsApp());

      final materialApp =
          find.byType(MaterialApp).evaluate().first.widget as MaterialApp;
      expect(materialApp.theme?.useMaterial3, isTrue);
    });

    testWidgets('renders home screen', (WidgetTester tester) async {
      await tester.pumpWidget(const KineticKidsApp());

      expect(find.byType(KidsHomeScreen), findsOneWidget);
    });

    testWidgets('home screen has app bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const KidsHomeScreen(),
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
      await tester.pumpWidget(
        MaterialApp(
          home: const KidsHomeScreen(),
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFFE7BB41),
            ),
          ),
        ),
      );

      expect(find.text('Mijn Opdrachten'), findsOneWidget);
    });
  });
}
