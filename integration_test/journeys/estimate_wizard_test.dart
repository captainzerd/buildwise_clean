import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter/material.dart';
import '../helpers/fixture_seeder.dart';
import '../helpers/test_app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await bootstrapTestApp();
    await seedFixtureUsers();
  });

  testWidgets('estimate wizard happy path — result screen shows non-zero total', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Sign in
    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    // Start new estimate
    await tester.tap(find.byKey(const Key('new_estimate_button')));
    await tester.pumpAndSettle();

    // Step 1: project name + region
    await tester.enterText(find.byKey(const Key('step1_project_name')), 'E2E Test');
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

    // Step 3: quality
    await tester.tap(find.byKey(const Key('step3_quality_standard')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 4: no extras — just proceed
    await tester.tap(find.byKey(const Key('wizard_next_button')));
    await tester.pumpAndSettle();

    // Step 5: review — check non-zero total label visible
    expect(find.byKey(const Key('step5_total_label')), findsOneWidget);

    // Calculate
    await tester.tap(find.byKey(const Key('calculate_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const Key('estimate_result_screen')), findsOneWidget);
    expect(find.byKey(const Key('total_planned_ghs_label')), findsOneWidget);

    // Verify the label text is not '0' or empty
    final totalLabel = tester.widget<Text>(
      find.byKey(const Key('total_planned_ghs_label')),
    );
    expect(totalLabel.data, isNotEmpty);
    expect(totalLabel.data, isNot('GHS 0'));
    expect(totalLabel.data, isNot('GHS 0.00'));
  });
}
