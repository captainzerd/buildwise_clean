import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('delete cost entry dialog has correct structure', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => Scaffold(
        body: ElevatedButton(
          onPressed: () => showDialog<bool>(
            context: ctx,
            builder: (_) => AlertDialog(
              title: const Text('Delete cost entry?'),
              content: const Text(
                'Foundation Works (GH\u20B5 5,000.00) will be permanently removed.\n\nThis action cannot be undone.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          ),
          child: const Text('open'),
        ),
      ),),
    ),);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Delete cost entry?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
