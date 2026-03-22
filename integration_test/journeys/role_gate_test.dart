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
  });

  tearDown(() async {
    await FirebaseAuth.instance.signOut();
  });

  testWidgets('contractor does not see create-project FAB', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in as contractor
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kContractorEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('home_shell')), findsOneWidget);

    // Navigate to Projects tab
    await tester.tap(find.byKey(const Key('projects_nav_tab')));
    await tester.pumpAndSettle();

    // FAB to create a new project must NOT be visible
    expect(find.byKey(const Key('create_project_fab')), findsNothing);
  });
}
