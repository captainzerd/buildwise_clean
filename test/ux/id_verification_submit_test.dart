import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wysebrix/core/widgets/loading_button.dart';

void main() {
  testWidgets('LoadingButton shows spinner while async work runs', (tester) async {
    var completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LoadingButton(
            label: 'Submit for Verification',
            icon: Icons.upload_outlined,
            onPressed: () async {
              await Future.delayed(const Duration(milliseconds: 100));
              completed = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Submit for Verification'), findsOneWidget);
    expect(find.byIcon(Icons.upload_outlined), findsOneWidget);

    await tester.tap(find.text('Submit for Verification'));
    await tester.pump();

    expect(find.text('Please wait…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(find.text('Submit for Verification'), findsOneWidget);
  });
}
