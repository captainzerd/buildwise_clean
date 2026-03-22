// test/widget_test.dart
// Smoke tests that do not require Firebase initialisation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Material app renders without error', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Text('WyseBrix')),
      ),
    );
    expect(find.text('WyseBrix'), findsOneWidget);
  });
}
