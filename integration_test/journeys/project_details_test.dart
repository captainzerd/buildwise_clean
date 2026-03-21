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

    // Open seeded project (find by title seeded in fixture_seeder)
    await tester.tap(find.text('E2E Seeded Project'));
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

  testWidgets('add variation order — appears in list', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.text('E2E Seeded Project'));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.tap(find.byKey(const Key('add_variation_order_button')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('vo_title_field')), 'Extra Excavation');
    await tester.enterText(find.byKey(const Key('vo_amount_field')), '5000');
    await tester.tap(find.byKey(const Key('vo_save_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.text('Extra Excavation'), findsOneWidget);
  });
}
