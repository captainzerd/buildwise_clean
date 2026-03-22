import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../auth/email_verification_page.dart';
import '../auth/sign_in_page.dart';

/// Wraps [child] and shows the appropriate auth screen if the user
/// is not signed in or has not verified their email.
///
/// Usage:
///   AuthGate(requireVerification: true, child: MyProtectedPage())
class AuthGate extends StatelessWidget {
  const AuthGate({
    super.key,
    required this.child,
    this.requireVerification = true,
  });

  final Widget child;

  /// When true, also blocks access until the user's email is verified.
  final bool requireVerification;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.isSignedIn) {
      return const SignInPage();
    }

    if (requireVerification && !auth.isEmailVerified) {
      return const EmailVerificationPage();
    }

    return child;
  }
}
