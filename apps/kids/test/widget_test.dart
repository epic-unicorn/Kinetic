import 'package:flutter_test/flutter_test.dart';
import 'package:kids/main.dart';
import 'package:kids/notifications/kids_notification_service.dart';
import 'helpers/test_database.dart';

void main() {
    testWidgets('KineticKidsApp smoke test', (WidgetTester tester) async {
    final appDb = createTestDatabase();
    try {
      final notificationService = KidsNotificationService();
      await tester.pumpWidget(
        KineticKidsApp(appDb: appDb, notificationService: notificationService),
      );
      // App should render without throwing.
      expect(find.byType(KineticKidsApp), findsOneWidget);
    } finally {
      await appDb.close();
    }
  });
}
