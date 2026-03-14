import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('switch role dialog has correct actions', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (ctx) => Scaffold(
          body: ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('Switch to Builder?'),
                content: const Text(
                  'You will be switched to Builder mode. You can switch back at any time.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Switch'),
                  ),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Switch to Builder?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);
  });
}
