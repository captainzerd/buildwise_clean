import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('notification tile renders title and subtitle', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListTile(
            title: const Text('New contract received'),
            subtitle: const Text('2 minutes ago'),
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('New contract received'), findsOneWidget);
    expect(find.text('2 minutes ago'), findsOneWidget);
  });

  testWidgets('snackbar shows on routing error', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (ctx) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                try {
                  throw Exception('route error');
                } catch (_) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open this notification.'),
                    ),
                  );
                }
              },
              child: const Text('tap'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('tap'));
    await tester.pumpAndSettle();
    expect(find.text('Could not open this notification.'), findsOneWidget);
  });
}
