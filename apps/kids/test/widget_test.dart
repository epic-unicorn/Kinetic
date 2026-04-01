import 'package:flutter_test/flutter_test.dart';
import 'package:kids/db/app_database.dart';
import 'package:kids/main.dart';

void main() {
  testWidgets('KineticKidsApp smoke test', (WidgetTester tester) async {
    final appDb = AppDatabase();
    await tester.pumpWidget(KineticKidsApp(appDb: appDb));
    // App should render without throwing.
    expect(find.byType(KineticKidsApp), findsOneWidget);
  });
}
