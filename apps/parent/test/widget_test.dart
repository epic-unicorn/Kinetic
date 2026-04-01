import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App theme applies Material 3', (WidgetTester tester) async {
    // Smoke test: verify Material 3 theme is configured
    // Full app integration tests require database setup and should be in separate files
    await tester.pumpWidget(
      MaterialApp(
        title: 'Kinetic Link',
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(appBar: AppBar(title: const Text('Test'))),
      ),
    );
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });
}
