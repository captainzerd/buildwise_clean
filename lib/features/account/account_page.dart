import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/services/auth_service.dart';
import '../estimate/saved_estimates_page.dart';
import 'builder_profile_page.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.currentUser;

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _AvatarHeader(user: user),
          const SizedBox(height: 32),
          _InfoSection(user: user),
          const SizedBox(height: 24),
          if (user.role == UserRole.pm) ...[
            _BuilderProfileTile(),
            const SizedBox(height: 24),
          ],
          _SavedEstimatesTile(),
          const SizedBox(height: 24),
          if (!user.emailVerified) _VerificationBanner(auth: auth),
          const SizedBox(height: 32),
          _SignOutButton(auth: auth),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Avatar + name header
// ─────────────────────────────────────────────

class _AvatarHeader extends StatelessWidget {
  const _AvatarHeader({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(user.displayName);
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: cs.primaryContainer,
          backgroundImage:
              user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
          child: user.photoUrl == null
              ? Text(
                  initials,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          user.displayName.isNotEmpty ? user.displayName : 'No name set',
          style: Theme.of(context).textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Chip(
          label: Text(user.role.label),
          avatar: Icon(
            _roleIcon(user.role),
            size: 16,
          ),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  IconData _roleIcon(UserRole role) => switch (role) {
        UserRole.owner => Icons.home_outlined,
        UserRole.pm => Icons.engineering_outlined,
        UserRole.admin => Icons.admin_panel_settings_outlined,
      };
}

// ─────────────────────────────────────────────
// Info tiles
// ─────────────────────────────────────────────

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          _InfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
            trailing: user.emailVerified
                ? const _VerifiedBadge()
                : const _UnverifiedBadge(),
          ),
          const Divider(height: 0, indent: 56),
          _InfoTile(
            icon: Icons.badge_outlined,
            label: 'Role',
            value: user.role.label,
          ),
          if (user.phone != null) ...[
            const Divider(height: 0, indent: 56),
            _InfoTile(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone!,
            ),
          ],
          const Divider(height: 0, indent: 56),
          _InfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Member since',
            value: _formatDate(user.createdAt),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day} ${_month(d.month)} ${d.year}';

  String _month(int m) => const [
        '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
      ][m];
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(label, style: Theme.of(context).textTheme.labelSmall),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyMedium),
      trailing: trailing,
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  const _VerifiedBadge();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 4),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      );
}

class _UnverifiedBadge extends StatelessWidget {
  const _UnverifiedBadge();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.warning_amber_outlined,
            size: 16,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 4),
          Text(
            'Unverified',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.error,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────
// PM profile link
// ─────────────────────────────────────────────

class _BuilderProfileTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.engineering_outlined),
        title: const Text('Manage Builder Profile'),
        subtitle: const Text('Set up your public builder listing'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BuilderProfilePage()),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Saved estimates link
// ─────────────────────────────────────────────

class _SavedEstimatesTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.history),
        title: const Text('Saved Estimates'),
        subtitle: const Text('View your previously generated estimates'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SavedEstimatesPage()),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Email verification banner
// ─────────────────────────────────────────────

class _VerificationBanner extends StatefulWidget {
  const _VerificationBanner({required this.auth});
  final AuthService auth;

  @override
  State<_VerificationBanner> createState() => _VerificationBannerState();
}

class _VerificationBannerState extends State<_VerificationBanner> {
  bool _busy = false;

  Future<void> _resend() async {
    setState(() => _busy = true);
    try {
      await widget.auth.sendEmailVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send email. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_outlined, color: cs.onErrorContainer),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email not verified',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: cs.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Some features require a verified email.',
                  style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy ? null : _resend,
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Resend'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sign out
// ─────────────────────────────────────────────

class _SignOutButton extends StatelessWidget {
  const _SignOutButton({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
        side: BorderSide(color: Theme.of(context).colorScheme.error),
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () async {
        await auth.signOut();
        if (context.mounted) Navigator.of(context).pop();
      },
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
    );
  }
}
