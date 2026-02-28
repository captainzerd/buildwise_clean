import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../account/account_page.dart';
import '../auth/email_verification_page.dart';
import '../auth/sign_in_page.dart';
import '../../core/widgets/theme_mode_action.dart';
import '../complaints/complaints_page.dart';
import '../estimate/estimate_page.dart';
import '../project/builder_marketplace_page.dart';
import '../project/projects_page.dart';
import '../vendor/vendors_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _tabs = [
    _TabDef('Estimate', Icons.calculate_outlined, Icons.calculate),
    _TabDef('Projects', Icons.work_outline, Icons.work),
    _TabDef('Find a Builder', Icons.people_outline, Icons.people),
    _TabDef('Vendors', Icons.store_mall_directory_outlined, Icons.store_mall_directory),
    _TabDef('Complaints', Icons.report_problem_outlined, Icons.report_problem),
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_tabs[_index].title),
        actions: [
          const ThemeModeAction(),
          IconButton(
            tooltip: auth.isSignedIn ? 'Account' : 'Sign in',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => _openAccount(context, auth),
          ),
        ],
      ),
      body: _buildBody(auth),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in _tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.title,
            ),
        ],
      ),
    );
  }

  Widget _buildBody(AuthService auth) {
    return switch (_index) {
      0 => const EstimatePage(),
      1 => _AuthGuard(auth: auth, child: const ProjectsPage()),
      2 => const BuilderMarketplacePage(),
      3 => _AuthGuard(auth: auth, child: const VendorsPage()),
      4 => _AuthGuard(auth: auth, child: const ComplaintsPage()),
      _ => const SizedBox.shrink(),
    };
  }

  void _openAccount(BuildContext context, AuthService auth) {
    if (!auth.isSignedIn) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SignInPage()),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AccountPage()),
    );
  }
}

// ─────────────────────────────────────────────
// Auth guard for tabs that require sign-in
// ─────────────────────────────────────────────

class _AuthGuard extends StatelessWidget {
  const _AuthGuard({required this.auth, required this.child});

  final AuthService auth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!auth.isSignedIn) {
      return _SignInPrompt(
        onSignIn: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SignInPage()),
        ),
      );
    }

    if (!auth.isEmailVerified) {
      return const EmailVerificationPage();
    }

    return child;
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onSignIn});
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.lock_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Sign in required',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Create a free account or sign in to access this section.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onSignIn,
                icon: const Icon(Icons.login),
                label: const Text('Sign in / Create account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab definition
// ─────────────────────────────────────────────

class _TabDef {
  const _TabDef(this.title, this.icon, this.selectedIcon);
  final String title;
  final IconData icon;
  final IconData selectedIcon;
}
