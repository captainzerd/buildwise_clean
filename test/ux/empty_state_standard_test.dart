import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/widgets/empty_state.dart';

void main() {
  testWidgets('EmptyState renders icon, title, and message without button',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.notifications_none_outlined,
            title: 'No notifications yet',
            message: 'You\'ll see alerts here.',
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.notifications_none_outlined), findsOneWidget);
    expect(find.text('No notifications yet'), findsOneWidget);
    expect(find.text('You\'ll see alerts here.'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('EmptyState shows no button when actionLabel is null',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.search_off_outlined,
            title: 'No matches',
          ),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });
}
