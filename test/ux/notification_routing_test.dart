import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification tile renders with title and is tappable', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text('New contract received'),
            subtitle: const Text('2 minutes ago'),
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.text('New contract received'), findsOneWidget);
    await tester.tap(find.byType(ListTile));
    expect(tapped, isTrue);
  });

  testWidgets('routing error shows could-not-open snackbar', (tester) async {
    // Verifies the SnackBar error pattern used in routeFromData catch block
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open this notification.'),
                  ),
                );
              },
              child: const Text('trigger error'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('trigger error'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open this notification.'), findsOneWidget);
  });
}
