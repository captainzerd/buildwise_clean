// lib/features/shell/home_shell.dart
//
// Primary navigation shell — 4 tabs:
//   0  Estimate       – always accessible
//   1  Projects       – email-verified (owners "Projects"; builders "My Work")
//   3  Find Builders  – builder marketplace (public)
//   4  Account        – always accessible; shows sign-in prompt when logged out
//
// Badge: Projects tab shows a count of pending deletion requests for owners.

import '../../core/config/service_locator.dart';
import '../../core/services/app_version_service.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/deletion_request.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/deletion_request_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/coach_mark_overlay.dart';
import '../../core/widgets/offline_banner.dart';
import '../account/account_page.dart';
import '../auth/email_verification_page.dart';
import '../estimate/estimate_page.dart';
import '../project/builder_marketplace_page.dart';
import '../project/projects_page.dart';
import '../../core/widgets/theme_mode_action.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  // Tab index constants — makes switch() readable.
  static const _kEstimate = 0;
  static const _kProjects = 1;
  static const _kPeople = 3;
  static const _kAccount = 4;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(_lifecycleObserver);
  }

  late final _AppLifecycleObserver _lifecycleObserver =
      _AppLifecycleObserver(onResume: () => context.read<AppVersionService>().check());

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(_lifecycleObserver);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final versionConfig = context.watch<AppVersionService>().config;
    if (versionConfig.state == AppVersionState.blocked) {
      return _VersionBlockedScreen(config: versionConfig);
    }
    final auth = context.watch<AuthService>();

    // Compute the ordered list of tab indices visible to this role.
    final visibleIndices = (auth.isSignedIn
            ? auth.role.visibleTabIndices
            : const {0, 1, 3, 4})
        .toList()
      ..sort();

    // Reset to first visible tab whenever the current tab leaves the allowed set
    // (e.g. role switch, sign-out).
    if (!visibleIndices.contains(_index)) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) { if (mounted) setState(() => _index = visibleIndices.first); },
      );
    }
    final projectsLabel =
        auth.isSignedIn ? auth.role.projectsTabLabel : 'Projects';

    // Only project owners get the deletion-request badge stream.
    final showOwnerBadges =
        auth.isSignedIn && auth.role.canCreateProject;

    // Account and Estimate tabs supply their own AppBar (inner Scaffold).
    // All other tabs are wrapped in the outer Scaffold AppBar.
    final onCustomAppBarTab = _index == _kAccount || _index == _kEstimate;

    return Scaffold(
      key: const Key('home_shell'),
      appBar: onCustomAppBarTab
          ? null
          : AppBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Image.asset('assets/images/logo.png', height: 26),
                  ),
                  const Text('WyseBrix', style: TextStyle(fontSize: 11)),
                ],
              ),
              centerTitle: true,
              actions: [
                const ThemeModeAction(),
                if (auth.isSignedIn)
                  _NotificationBell(uid: auth.currentUser!.uid),
              ],
            ),
      body: Column(
        children: [
          if (versionConfig.state == AppVersionState.nudge)
            _UpdateBanner(config: versionConfig),
          const OfflineBanner(),
          Expanded(
            child: CoachMarkOverlay(child: _buildBody(auth)),
          ),
        ],
      ),
      bottomNavigationBar: showOwnerBadges
          ? StreamBuilder<List<DeletionRequest>>(
              stream: sl<DeletionRequestService>().allPendingStream(),
              builder: (_, deletionSnap) {
                final uid = auth.currentUser!.uid;
                return StreamBuilder<int>(
                  stream: sl<NotificationService>().unreadChatCountStream(uid),
                  builder: (_, chatSnap) => _NavBar(
                    logicalIndex: _index,
                    visibleIndices: visibleIndices,
                    projectsLabel: projectsLabel,
                    pendingDeletions: deletionSnap.data?.length ?? 0,
                    unreadChats: chatSnap.data ?? 0,
                    onTap: (i) => setState(() => _index = i),
                  ),
                );
              },
            )
          : _NavBar(
              logicalIndex: _index,
              visibleIndices: visibleIndices,
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
        _kPeople => const BuilderMarketplacePage(),
        _kAccount => AccountPage(embedded: true, auth: auth),
        _ => const SizedBox.shrink(),
      };
}

// ─────────────────────────────────────────────
// Navigation bar widget — role-aware dynamic tabs
// ─────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  const _NavBar({
    required this.logicalIndex,
    required this.visibleIndices,
    required this.projectsLabel,
    required this.pendingDeletions,
    required this.unreadChats,
    required this.onTap,
  });

  /// The currently selected logical tab index (0–4).
  final int logicalIndex;

  /// Sorted list of logical indices that are visible for the current role.
  final List<int> visibleIndices;

  final String projectsLabel;
  final int pendingDeletions;
  final int unreadChats;

  /// Called with the *logical* index when the user taps a destination.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final selectedVisibleIndex =
        visibleIndices.indexOf(logicalIndex).clamp(0, visibleIndices.length - 1);

    return NavigationBar(
      selectedIndex: selectedVisibleIndex,
      onDestinationSelected: (i) => onTap(visibleIndices[i]),
      destinations: [
        for (final i in visibleIndices) _destination(i),
      ],
    );
  }

  NavigationDestination _destination(int logicalI) => switch (logicalI) {
        0 => const NavigationDestination(
            key: Key('new_estimate_button'),
            icon: Icon(Icons.calculate_outlined),
            selectedIcon: Icon(Icons.calculate),
            label: 'Estimate',
          ),
        1 => NavigationDestination(
            key: const Key('projects_nav_tab'),
            icon: Semantics(
              label: [
                if (pendingDeletions > 0)
                  '$pendingDeletions pending deletion request${pendingDeletions == 1 ? '' : 's'}',
                if (unreadChats > 0)
                  '$unreadChats unread chat message${unreadChats == 1 ? '' : 's'}',
              ].join(', '),
              child: Badge(
                isLabelVisible: pendingDeletions > 0,
                label:
                    Text(pendingDeletions > 99 ? '99+' : '$pendingDeletions'),
                child: Badge(
                  isLabelVisible: unreadChats > 0,
                  label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                  alignment: AlignmentDirectional.bottomStart,
                  child: const Icon(Icons.work_outline),
                ),
              ),
            ),
            selectedIcon: Semantics(
              label: [
                if (pendingDeletions > 0)
                  '$pendingDeletions pending deletion request${pendingDeletions == 1 ? '' : 's'}',
                if (unreadChats > 0)
                  '$unreadChats unread chat message${unreadChats == 1 ? '' : 's'}',
              ].join(', '),
              child: Badge(
                isLabelVisible: pendingDeletions > 0,
                label:
                    Text(pendingDeletions > 99 ? '99+' : '$pendingDeletions'),
                child: Badge(
                  isLabelVisible: unreadChats > 0,
                  label: Text(unreadChats > 99 ? '99+' : '$unreadChats'),
                  alignment: AlignmentDirectional.bottomStart,
                  child: const Icon(Icons.work),
                ),
              ),
            ),
            label: projectsLabel,
          ),
        3 => const NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Find Builders',
          ),
        4 => const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Account',
          ),
        _ => throw ArgumentError('Unknown logical tab index: $logicalI'),
      };
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

// ─────────────────────────────────────────
// Version update UI
// ─────────────────────────────────────────

class _UpdateBanner extends StatefulWidget {
  const _UpdateBanner({required this.config});
  final AppVersionConfig config;

  @override
  State<_UpdateBanner> createState() => _UpdateBannerState();
}

class _UpdateBannerState extends State<_UpdateBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    return MaterialBanner(
      content: Text(widget.config.message),
      actions: [
        TextButton(
          onPressed: () => setState(() => _dismissed = true),
          child: const Text('Later'),
        ),
        FilledButton(
          onPressed: () => _openStore(widget.config.storeUrl),
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _VersionBlockedScreen extends StatelessWidget {
  const _VersionBlockedScreen({required this.config});
  final AppVersionConfig config;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.system_update_outlined,
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  'Update Required',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  config.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: () => _openStore(config.storeUrl),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Update WyseBrix'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppLifecycleObserver extends WidgetsBindingObserver {
  _AppLifecycleObserver({required this.onResume});
  final VoidCallback onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) onResume();
  }
}

Future<void> _openStore(String url) async {
  if (url.isEmpty) return;
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
        return Semantics(
          label: count > 0
              ? '$count unread notification${count == 1 ? '' : 's'}'
              : 'Notifications',
          button: true,
          child: IconButton(
            tooltip: 'Notifications',
            onPressed: () => context.push('/notifications'),
            icon: Badge(
              isLabelVisible: count > 0,
              label: Text(count > 99 ? '99+' : '$count'),
              child: const Icon(Icons.notifications_outlined),
            ),
          ),
        );
      },
    );
  }
}
