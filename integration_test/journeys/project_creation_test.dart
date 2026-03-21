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

  testWidgets('estimate wizard result screen shows save-as-project button', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Navigate through estimate wizard
    await tester.tap(find.byKey(const Key('new_estimate_button')));
    await tester.pumpAndSettle();

    // Step 1: project name + region
    await tester.enterText(find.byKey(const Key('step1_project_name')), 'E2E Create Test');
    await tester.tap(find.byKey(const Key('step1_region_dropdown')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Greater Accra'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 2: typology
    await tester.tap(find.byKey(const Key('step2_typology_residential_standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 3: quality (already defaults to Standard)
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 4: no extras
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Calculate from Step 5 review
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Verify result screen and save button are visible
    expect(find.byKey(const Key('estimate_result_screen')), findsOneWidget);
    expect(find.byKey(const Key('save_as_project_button')), findsOneWidget);
  });
}
