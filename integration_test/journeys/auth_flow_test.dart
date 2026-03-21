// HOW TO RUN:
//   Terminal 1: firebase emulators:start --only auth,firestore
//   Terminal 2: flutter test integration_test/ -d <ios-simulator-id> --dart-define=ENV=test
//
// Get simulator ID: xcrun simctl list devices | grep Booted

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

  testWidgets('cold launch shows sign-in screen', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));
    expect(find.byKey(const Key('sign_in_email_field')), findsOneWidget);
  });

  testWidgets('sign in as owner loads home shell', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(
      find.byKey(const Key('sign_in_email_field')), kOwnerEmail,
    );
    await tester.enterText(
      find.byKey(const Key('sign_in_password_field')), kTestPassword,
    );
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('home_shell')), findsOneWidget);
  });

  testWidgets('sign out returns to sign-in screen', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kOwnerEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await tester.tap(find.byKey(const Key('sign_out_button')));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(find.byKey(const Key('sign_in_email_field')), findsOneWidget);
  });

  testWidgets('unverified user sees email verification gate, not home shell', (tester) async {
    await tester.pumpWidget(testAppWidget());
    await tester.pumpAndSettle(const Duration(seconds: 3));

    await tester.enterText(find.byKey(const Key('sign_in_email_field')), kUnverifiedEmail);
    await tester.enterText(find.byKey(const Key('sign_in_password_field')), kTestPassword);
    await tester.tap(find.byKey(const Key('sign_in_submit_button')));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    expect(find.byKey(const Key('email_verification_gate')), findsOneWidget);
    expect(find.byKey(const Key('home_shell')), findsNothing);
  });
}
