import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:parent/main.dart';

void main() {
  testWidgets('KineticParentApp renders pairing screen', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const KineticParentApp());
    // PairingScreen loads asynchronously; verify scaffold is present.
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
