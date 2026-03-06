// lib/features/onboarding/onboarding_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kOnboardingDone = 'onboarding_done';

/// Returns true if the user has already seen the onboarding screen.
Future<bool> isOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingDone) ?? false;
}

Future<void> _markOnboardingDone() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingDone, true);
}

// ── Page ──────────────────────────────────────────────────────────────────────

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _controller = PageController();
  int _page = 0;

  static const _pages = [
    _PageData(
      icon: Icons.calculate_outlined,
      title: 'Estimate construction costs instantly',
      body: 'Get accurate Ghana-region cost estimates based on '
          'real surveyor data. Switch between GHS, USD, GBP and more with live FX rates.',
    ),
    _PageData(
      icon: Icons.work_outline,
      title: 'Track every project in one place',
      body: 'Manage phases, record costs, upload site photos, '
          'attach receipts, and share PDF reports — all from your phone.',
    ),
    _PageData(
      icon: Icons.people_outline,
      title: 'Find builders, PMs & vendors',
      body: 'Browse rated contractors and project managers, '
          'send digital contracts, and source building materials from verified suppliers.',
    ),
    // Role explanation slide — rendered separately as _RolesSlide
    _PageData(
      icon: Icons.person_outline,
      title: 'Who are you building for?',
      body: '',
    ),
  ];

  void _next() {
    if (_page < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    await _markOnboardingDone();
    if (!mounted) return;
    GoRouter.of(context).go('/');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isLast = _page == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Logo + skip row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Image.asset('assets/images/logo.png', height: 36),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => i == 3
                    ? const _RolesSlide()
                    : _OnboardPage(data: _pages[i]),
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i == _page ? 20 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: i == _page ? cs.primary : cs.outlineVariant,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // CTA button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _next,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(isLast ? 'Get started' : 'Next'),
                ),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  const _OnboardPage({required this.data});
  final _PageData data;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, size: 56, color: cs.onPrimaryContainer),
          ),
          const SizedBox(height: 40),
          Text(
            data.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            data.body,
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _PageData {
  const _PageData({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;
}

// ── Roles slide ────────────────────────────────────────────────────────────────

class _RolesSlide extends StatelessWidget {
  const _RolesSlide();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Who are you building for?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'BuildWise supports three types of accounts.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _RoleCard(
            icon: Icons.home_outlined,
            title: 'Property Owner',
            description:
                'Create and manage your construction projects, '
                'hire builders, approve payments, and track progress.',
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.engineering_outlined,
            title: 'Project Manager',
            description:
                'Oversee client projects, record costs, submit '
                'site reports, and manage site teams on behalf of owners.',
          ),
          const SizedBox(height: 12),
          _RoleCard(
            icon: Icons.construction_outlined,
            title: 'Builder / Contractor',
            description:
                'List your services in the marketplace, receive '
                'project invitations, sign digital contracts, and get paid.',
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: cs.primary, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
