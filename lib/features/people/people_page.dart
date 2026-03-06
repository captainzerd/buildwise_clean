// lib/features/people/people_page.dart
//
// Combines the PM/Builder marketplace and Vendor directory in a single tab.
// A SegmentedButton at the top lets the user toggle between the two sections.
// Marketplace is public; Vendors requires email verification.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../project/marketplace_page.dart';
import '../vendor/vendors_page.dart';

enum _Section { marketplace, vendors }

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});

  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  _Section _section = _Section.marketplace;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // ── Section toggle ────────────────────────────────────────────────
        Container(
          color: cs.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SegmentedButton<_Section>(
            expandedInsets: EdgeInsets.zero,
            segments: const [
              ButtonSegment(
                value: _Section.marketplace,
                label: Text('Find Help'),
                icon: Icon(Icons.people_outline),
              ),
              ButtonSegment(
                value: _Section.vendors,
                label: Text('Vendors'),
                icon: Icon(Icons.storefront_outlined),
              ),
            ],
            selected: {_section},
            onSelectionChanged: (s) => setState(() => _section = s.first),
          ),
        ),
        const Divider(height: 1),

        // ── Content ──────────────────────────────────────────────────────
        Expanded(
          child: IndexedStack(
            index: _section.index,
            children: [
              const MarketplacePage(),
              _VendorSection(auth: auth),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Vendor section with auth gate ──────────────────────────────────────────

class _VendorSection extends StatelessWidget {
  const _VendorSection({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    if (!auth.isSignedIn) {
      return _AuthPrompt(
        icon: Icons.storefront_outlined,
        title: 'Sign in to browse vendors',
        message:
            'Create a free account to search and contact verified suppliers '
            'and contractors in your region.',
        onSignIn: () => context.push('/sign-in'),
      );
    }

    if (!auth.isEmailVerified) {
      return const _VerifyEmailPrompt();
    }

    return const VendorsPage(embedded: true);
  }
}

// ── Auth prompt widget ──────────────────────────────────────────────────────

class _AuthPrompt extends StatelessWidget {
  const _AuthPrompt({
    required this.icon,
    required this.title,
    required this.message,
    required this.onSignIn,
  });

  final IconData icon;
  final String title;
  final String message;
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
                icon,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
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

// ── Verify email prompt ─────────────────────────────────────────────────────

class _VerifyEmailPrompt extends StatelessWidget {
  const _VerifyEmailPrompt();

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
                Icons.mark_email_unread_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Verify your email',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'A verified email is required to access the vendor directory. '
                'Check your inbox for a verification link.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: () => context.push('/email-verification'),
                icon: const Icon(Icons.verified_user_outlined),
                label: const Text('Go to email verification'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
