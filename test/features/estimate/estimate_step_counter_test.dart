import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildCounter(int step) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('Step ${step + 1} of 5'),
              ),
              LinearProgressIndicator(value: (step + 1) / 5),
            ],
          ),
        ),
      ),
    ),
  );

  testWidgets('shows Step 1 of 5 on first step', (tester) async {
    await tester.pumpWidget(buildCounter(0));
    expect(find.text('Step 1 of 5'), findsOneWidget);
  });

  testWidgets('shows Step 3 of 5 on third step', (tester) async {
    await tester.pumpWidget(buildCounter(2));
    expect(find.text('Step 3 of 5'), findsOneWidget);
  });
}
