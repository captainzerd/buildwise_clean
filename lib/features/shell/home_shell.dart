// lib/features/shell/home_shell.dart
//
// Primary navigation shell — 5 tabs:
//   0  Estimate   – always accessible
//   1  Projects   – email-verified (owners "Projects"; builders "My Work")
//   2  Analytics  – email-verified, owner-only content
//   3  People     – Marketplace (public) + Vendors (email-verified) combined
//   4  Account    – always accessible; shows sign-in prompt when logged out
//
// Badge: Projects tab shows a count of pending deletion requests for owners.

import '../../core/config/service_locator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/deletion_request.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/deletion_request_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/offline_banner.dart';
import '../account/account_page.dart';
import '../analytics/analytics_page.dart';
import '../auth/email_verification_page.dart';
import '../estimate/estimate_page.dart';
import '../people/people_page.dart';
import '../project/projects_page.dart';
import '../../core/widgets/theme_mode_action.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _wasSignedIn = false;

  // Tab index constants — makes switch() readable.
  static const _kEstimate = 0;
  static const _kProjects = 1;
  static const _kAnalytics = 2;
  static const _kPeople = 3;
  static const _kAccount = 4;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final isOwner = auth.isSignedIn && auth.role == UserRole.owner;

    // Reset to Estimate tab when user signs out from a protected tab.
    if (_wasSignedIn && !auth.isSignedIn &&
        (_index == _kProjects || _index == _kAnalytics)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) { if (mounted) setState(() => _index = _kEstimate); },
      );
    }
    _wasSignedIn = auth.isSignedIn;

    // Projects tab label is role-aware.
    final projectsLabel =
        auth.isSignedIn && auth.role == UserRole.pm ? 'My Work' : 'Projects';

    // Account tab is rendered as the full page (embedded — no inner AppBar).
    // All other tabs are wrapped in the outer Scaffold AppBar.
    final onAccountTab = _index == _kAccount;

    return Scaffold(
      appBar: onAccountTab
          ? null // AccountPage supplies its own AppBar
          : AppBar(
              title: Image.asset('assets/images/logo.png', height: 32),
              centerTitle: true,
              actions: [
                const ThemeModeAction(),
                if (auth.isSignedIn)
                  _NotificationBell(uid: auth.currentUser!.uid),
              ],
            ),
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: _buildBody(auth)),
        ],
      ),
      bottomNavigationBar: isOwner
          ? StreamBuilder<List<DeletionRequest>>(
              stream: sl<DeletionRequestService>().allPendingStream(),
              builder: (_, deletionSnap) {
                final uid = auth.currentUser!.uid;
                return StreamBuilder<int>(
                  stream: sl<NotificationService>().unreadChatCountStream(uid),
                  builder: (_, chatSnap) => _NavBar(
                    index: _index,
                    projectsLabel: projectsLabel,
                    pendingDeletions: deletionSnap.data?.length ?? 0,
                    unreadChats: chatSnap.data ?? 0,
                    onTap: (i) => setState(() => _index = i),
                  ),
                );
              },
            )
          : _NavBar(
              index: _index,
              projectsLabel: projectsLabel,
              pendingDeletions: 0,
              unreadChats: 0,
              onTap: (i) => setState(() => _index = i),
            ),
    );
  }

  Widget _buildBody(AuthService auth) => switch (_index) {
        _kEstimate => const EstimatePage(),
        _kProjects => _AuthGuard(auth: auth, child: const ProjectsPage()),
        _kAnalytics => _AuthGuard(auth: auth, child: const AnalyticsPage()),
        _kPeople => const PeoplePage(),
        _kAccount => AccountPage(embedded: true, auth: auth),
        _ => const SizedBox.shrink(),
      };
}

// ─────────────────────────────────────────────
// Navigation bar widget
// ─────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.index,
    required this.projectsLabel,
    required this.pendingDeletions,
    required this.unreadChats,
    required this.onTap,
  });

  final int index;
  final String projectsLabel;
  final int pendingDeletions;
  final int unreadChats;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onTap,
      destinations: [
        const NavigationDestination(
          icon: Icon(Icons.calculate_outlined),
          selectedIcon: Icon(Icons.calculate),
          label: 'Estimate',
        ),
        NavigationDestination(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Badge(
                isLabelVisible: pendingDeletions > 0,
                label: Text(
                  pendingDeletions > 99 ? '99+' : '$pendingDeletions',
                ),
                child: const Icon(Icons.work_outline),
              ),
              if (unreadChats > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Badge(
                    label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                  ),
                ),
            ],
          ),
          selectedIcon: Stack(
            clipBehavior: Clip.none,
            children: [
              Badge(
                isLabelVisible: pendingDeletions > 0,
                label: Text(
                  pendingDeletions > 99 ? '99+' : '$pendingDeletions',
                ),
                child: const Icon(Icons.work),
              ),
              if (unreadChats > 0)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Badge(
                    label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                  ),
                ),
            ],
          ),
          label: projectsLabel,
        ),
        const NavigationDestination(
          icon: Icon(Icons.analytics_outlined),
          selectedIcon: Icon(Icons.analytics),
          label: 'Analytics',
        ),
        const NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'People',
        ),
        const NavigationDestination(
          icon: Icon(Icons.person_outline),
          selectedIcon: Icon(Icons.person),
          label: 'Account',
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Auth guards
// ─────────────────────────────────────────────

class _AuthGuard extends StatelessWidget {
  const _AuthGuard({required this.auth, required this.child});

  final AuthService auth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!auth.isSignedIn) {
      return _SignInPrompt(
        onSignIn: () => context.push('/sign-in'),
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
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
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
// Notification bell with unread badge
// ─────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: sl<NotificationService>().unreadCountStream(uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          onPressed: () => context.push('/notifications'),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
