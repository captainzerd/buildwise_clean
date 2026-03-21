import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
    await seedTestProject();
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('project detail tabs render without error', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in as owner
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Navigate to projects screen first
    await tester.tap(find.byKey(const Key('projects_nav_tab')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Open seeded project (scoped to projects screen to avoid ambiguity)
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('projects_screen')),
        matching: find.text('E2E Seeded Project'),
      ).first,
    );
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const Key('project_details_screen')), findsOneWidget);

    // Finance tab
    await tester.tap(find.byKey(const Key('finance_tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Overview tab
    await tester.tap(find.byKey(const Key('overview_tab')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
