import 'package:flutter_test/flutter_test.dart';
import 'package:kids/main.dart';

void main() {
  testWidgets('KineticKidsApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KineticKidsApp());
    // App should render without throwing.
    expect(find.byType(KineticKidsApp), findsOneWidget);
  });
}
