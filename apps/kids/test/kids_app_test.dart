import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kids/main.dart';
import 'package:kids/notifications/kids_notification_service.dart';
import 'package:kids/task/screens/kids_home_screen.dart';
import 'helpers/test_database.dart';

void main() {
  group('KineticKidsApp', () {
    testWidgets('app builds without error', (WidgetTester tester) async {
      final appDb = createTestDatabase();
      try {
        final notificationService = KidsNotificationService();
        await tester.pumpWidget(
          KineticKidsApp(appDb: appDb, notificationService: notificationService),
        );
        expect(find.byType(MaterialApp), findsOneWidget);
      } finally {
        await appDb.close();
      }
    });

    testWidgets('uses Material 3 theme', (WidgetTester tester) async {
      final appDb = createTestDatabase();
      try {
        final notificationService = KidsNotificationService();
        await tester.pumpWidget(
          KineticKidsApp(appDb: appDb, notificationService: notificationService),
        );

        final materialApp =
            find.byType(MaterialApp).evaluate().first.widget as MaterialApp;
        expect(materialApp.theme?.useMaterial3, isTrue);
      } finally {
        await appDb.close();
      }
    });

    testWidgets('renders home screen', (WidgetTester tester) async {
      final appDb = createTestDatabase();
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: KidsHomeScreen(appDb: appDb),
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFF97316),
                brightness: Brightness.dark,
              ),
            ),
          ),
        );

        expect(find.byType(KidsHomeScreen), findsOneWidget);
      } finally {
        await appDb.close();
      }
    });

    testWidgets('home screen has app bar', (WidgetTester tester) async {
      final appDb = createTestDatabase();
      try {
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
      } finally {
        await appDb.close();
      }
    });

    testWidgets('home screen displays title', (WidgetTester tester) async {
      final appDb = createTestDatabase();
      try {
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
      } finally {
        await appDb.close();
      }
    });
  });
}
