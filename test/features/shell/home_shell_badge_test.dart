import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildBadgedIcon({
  required int primaryCount,
  required int secondaryCount,
}) =>
    MaterialApp(
      home: Scaffold(
        body: Badge(
          isLabelVisible: primaryCount > 0,
          label: Text('$primaryCount'),
          child: Badge(
            isLabelVisible: secondaryCount > 0,
            label: Text('$secondaryCount'),
            alignment: AlignmentDirectional.bottomStart,
            child: const Icon(Icons.work_outline),
          ),
        ),
      ),
    );

void main() {
  testWidgets('shows only primary badge when chats = 0', (tester) async {
    await tester.pumpWidget(
      buildBadgedIcon(primaryCount: 3, secondaryCount: 0),
    );
    expect(find.text('3'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('shows both badges when both > 0', (tester) async {
    await tester.pumpWidget(
      buildBadgedIcon(primaryCount: 2, secondaryCount: 5),
    );
    expect(find.text('2'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });

  testWidgets('shows only secondary badge when deletions = 0', (tester) async {
    await tester.pumpWidget(
      buildBadgedIcon(primaryCount: 0, secondaryCount: 4),
    );
    expect(find.text('4'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });
}
