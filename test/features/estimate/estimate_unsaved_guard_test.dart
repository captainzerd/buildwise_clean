import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('discard dialog has correct copy and actions', (tester) async {
    bool? dialogResult;

    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (ctx) => Scaffold(
        body: ElevatedButton(
          onPressed: () async {
            dialogResult = await showDialog<bool>(
              context: ctx,
              builder: (_) => AlertDialog(
                title: const Text('Discard changes?'),
                content: const Text('Your estimate progress will be lost.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep editing'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Discard'),
                  ),
                ],
              ),
            );
          },
          child: const Text('trigger'),
        ),
      ),),
    ),);

    await tester.tap(find.text('trigger'));
    await tester.pumpAndSettle();

    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Your estimate progress will be lost.'), findsOneWidget);
    expect(find.text('Keep editing'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(dialogResult, isTrue);
  });
}
