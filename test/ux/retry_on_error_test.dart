import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState shows retry button and fires onAction', (tester) async {
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Could not load',
            message: 'Check your connection.',
            actionLabel: 'Retry',
            onAction: () => taps++,
          ),
        ),
      ),
    );

    expect(find.text('Could not load'), findsOneWidget);
    expect(find.text('Check your connection.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.cloud_off_outlined), findsOneWidget);

    await tester.tap(find.text('Retry'));
    expect(taps, 1);
  });
}
