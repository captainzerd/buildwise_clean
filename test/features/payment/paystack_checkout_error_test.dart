import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('error state widget renders correctly', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.wifi_off_outlined, size: 64),
                SizedBox(height: 16),
                Text('Could not load payment page'),
                SizedBox(height: 8),
                Text('Check your connection and try again.'),
                SizedBox(height: 24),
                FilledButton.tonal(
                  onPressed: () {},
                  child: Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    ));

    expect(find.text('Could not load payment page'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
  });
}
