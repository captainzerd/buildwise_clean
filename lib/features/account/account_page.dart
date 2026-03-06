import '../../core/config/service_locator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/app_user.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/contract_service.dart';
import '../../core/services/csv_service.dart';
import '../../core/services/project_service.dart';
import '../../core/state/theme_mode_controller.dart';

class AccountPage extends StatelessWidget {
  /// [embedded] — when true the widget renders as plain content with no
  /// Scaffold or AppBar (used when hosted as a navigation tab in HomeShell).
  /// [auth] — required in embedded mode so the widget doesn't re-read from
  /// context (HomeShell already watches it).
  const AccountPage({
    super.key,
    this.embedded = false,
    this.auth,
  });

  final bool embedded;
  final AuthService? auth;

  @override
  Widget build(BuildContext context) {
    final effectiveAuth = auth ?? context.watch<AuthService>();
    final user = effectiveAuth.currentUser;

    // ── Not signed in ───────────────────────────────────────────────────────
    if (user == null) {
      final body = _SignedOutBody(
        onSignIn: () => context.push('/sign-in'),
      );
      if (embedded) return body;
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: body,
      );
    }

    // ── Signed in ───────────────────────────────────────────────────────────
    final listView = ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _AvatarHeader(user: user),
        const SizedBox(height: 24),
        _InfoSection(user: user),

        // ── Profile section (pm role only) ─────────────────────────────────
        if (user.role == UserRole.pm) ...[
          const SizedBox(height: 24),
          const _SectionHeader('Profile'),
          const SizedBox(height: 8),
          _BuilderProfileTile(),
          const SizedBox(height: 8),
          _PmProfileTile(),
        ],

        // ── Activity section ───────────────────────────────────────────────
        const SizedBox(height: 24),
        const _SectionHeader('Activity'),
        const SizedBox(height: 8),
        _SavedEstimatesTile(),
        if (user.role == UserRole.pm) ...[
          const SizedBox(height: 8),
          _PendingContractsTile(uid: user.uid),
          const SizedBox(height: 8),
          _QuoteRequestsTile(uid: user.uid),
        ],
        const SizedBox(height: 8),
        _ComplaintsTile(),

        // ── Settings section ───────────────────────────────────────────────
        const SizedBox(height: 24),
        const _SectionHeader('Settings'),
        const SizedBox(height: 8),
        if (user.role == UserRole.admin) ...[
          _AdminTile(),
          const SizedBox(height: 8),
        ],
        _ThemeModeTile(),
        const SizedBox(height: 8),
        _UpgradeTile(),
        const SizedBox(height: 8),
        _NotificationPrefsTile(),
        const SizedBox(height: 8),
        _ChangePasswordTile(auth: effectiveAuth),
        const SizedBox(height: 8),
        _SwitchRoleTile(auth: effectiveAuth),
        const SizedBox(height: 8),
        _ExportDataTile(uid: user.uid),
        const SizedBox(height: 8),
        _PrivacyPolicyTile(),
        const SizedBox(height: 8),
        _TermsOfServiceTile(),

        // ── Account section ────────────────────────────────────────────────
        const SizedBox(height: 24),
        const _SectionHeader('Account'),
        const SizedBox(height: 8),
        if (!user.emailVerified) ...[
          _VerificationBanner(auth: effectiveAuth),
          const SizedBox(height: 8),
        ],
        _SignOutButton(auth: effectiveAuth),
        const SizedBox(height: 8),
        _DeleteAccountButton(auth: effectiveAuth),
        const SizedBox(height: 16),
      ],
    );

    if (embedded) return listView;

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: listView,
    );
  }
}

// ── Signed-out body ────────────────────────────────────────────────────────

class _SignedOutBody extends StatelessWidget {
  const _SignedOutBody({required this.onSignIn});
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
                Icons.person_outline,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Your account',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to manage your profile, view saved estimates, '
                'and track your projects.',
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
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: cs.primaryContainer,
              backgroundImage: user.photoUrl != null
                  ? CachedNetworkImageProvider(user.photoUrl!)
                  : null,
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
            Material(
              shape: const CircleBorder(),
              color: cs.primary,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.push('/account/edit'),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.edit_outlined,
                    size: 14,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            ),
          ],
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
// Admin dashboard link
// ─────────────────────────────────────────────

class _AdminTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.admin_panel_settings_outlined),
        title: const Text('Admin Dashboard'),
        subtitle: const Text('Manage users, catalog and complaints'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/admin'),
      ),
    );
  }
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
        onTap: () => context.push('/account/profile/builder'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PM profile link
// ─────────────────────────────────────────────

class _PmProfileTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.architecture_outlined),
        title: const Text('Manage PM Profile'),
        subtitle: const Text('Set up your project manager listing'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/account/profile/pm'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Pending contracts link (builder role)
// ─────────────────────────────────────────────

class _PendingContractsTile extends StatelessWidget {
  const _PendingContractsTile({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final service = sl<ContractService>();
    return StreamBuilder<List<Object>>(
      stream: service.pendingForBuilder(uid),
      builder: (ctx, snap) {
        final count = snap.data?.length ?? 0;
        return Card(
          child: ListTile(
            leading: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              child: const Icon(Icons.description_outlined),
            ),
            title: const Text('Pending Contracts'),
            subtitle: Text(count > 0
                ? '$count contract${count == 1 ? '' : 's'} awaiting your signature'
                : 'No pending contracts',),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/account/contracts/pending'),
          ),
        );
      },
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
        onTap: () => context.push('/estimate/saved'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Quote requests inbox (builder / vendor role)
// ─────────────────────────────────────────────

class _QuoteRequestsTile extends StatelessWidget {
  const _QuoteRequestsTile({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.request_quote_outlined),
        title: const Text('Quote Requests'),
        subtitle: const Text('View and respond to incoming quote requests'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/account/rfq-inbox', extra: uid),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Complaints link (all signed-in users)
// ─────────────────────────────────────────────

class _ComplaintsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.report_problem_outlined),
        title: const Text('My Complaints'),
        subtitle: const Text('View and submit complaints or issues'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/complaints'),
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
// Notification preferences link
// ─────────────────────────────────────────────

class _NotificationPrefsTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notifications_outlined),
        title: const Text('Notification Preferences'),
        subtitle: const Text('Choose which notifications you receive'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/notifications/prefs'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Change password
// ─────────────────────────────────────────────

class _ChangePasswordTile extends StatelessWidget {
  const _ChangePasswordTile({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.lock_reset_outlined),
        title: const Text('Change Password'),
        subtitle: const Text('Update your account password'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => showDialog<void>(
          context: context,
          builder: (_) => _ChangePasswordDialog(auth: auth),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.auth});
  final AuthService auth;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await widget.auth.updatePassword(
        _currentPassCtrl.text,
        _newPassCtrl.text,
      );
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _currentPassCtrl,
              obscureText: _obscureCurrent,
              decoration: InputDecoration(
                labelText: 'Current password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureCurrent ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureCurrent ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _newPassCtrl,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureNew ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureNew ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v.length < 8) return 'Must be at least 8 characters';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmPassCtrl,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                if (v != _newPassCtrl.text) return 'Passwords do not match';
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update password'),
        ),
      ],
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
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text(
              'You will need to sign in again to access your projects.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Sign out'),
              ),
            ],
          ),
        );
        if (confirmed == true) await auth.signOut();
        // No navigation needed — HomeShell rebuilds reactively via AuthService.
      },
      icon: const Icon(Icons.logout),
      label: const Text('Sign out'),
    );
  }
}

// ─────────────────────────────────────────────
// Delete account
// ─────────────────────────────────────────────

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      style: TextButton.styleFrom(
        foregroundColor: Theme.of(context).colorScheme.error,
        minimumSize: const Size.fromHeight(48),
      ),
      onPressed: () => _confirmDelete(context),
      icon: const Icon(Icons.delete_forever_outlined),
      label: const Text('Delete account'),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final passwordCtrl = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This permanently deletes your account and all associated '
              'data. This action cannot be undone.\n\nEnter your password to confirm:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    final password = passwordCtrl.text;
    passwordCtrl.dispose();

    if (confirmed != true || password.isEmpty) return;

    try {
      await auth.deleteAccount(password);
      navigator.pop(); // pop AccountPage — HomeShell will show sign-in state
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    }
  }
}

// ─────────────────────────────────────────────
// Theme mode tile
// ─────────────────────────────────────────────

class _ThemeModeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeCtrl = context.watch<ThemeModeController>();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.palette_outlined),
                const SizedBox(width: 16),
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(
                  value: ThemeMode.system,
                  icon: Icon(Icons.brightness_auto, size: 18),
                  label: Text('System'),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  icon: Icon(Icons.light_mode, size: 18),
                  label: Text('Light'),
                ),
                ButtonSegment(
                  value: ThemeMode.dark,
                  icon: Icon(Icons.dark_mode, size: 18),
                  label: Text('Dark'),
                ),
              ],
              selected: {themeCtrl.mode},
              onSelectionChanged: (s) => themeCtrl.setMode(s.first),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Plans & Pricing tile
// ─────────────────────────────────────────────

class _UpgradeTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final tier = auth.currentUser?.subscriptionTier ?? SubscriptionTier.free;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.workspace_premium_outlined),
        title: const Text('Plans & Pricing'),
        subtitle: Text('Current plan: ${tier.label}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/account/upgrade'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Privacy Policy tile
// ─────────────────────────────────────────────

class _PrivacyPolicyTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.privacy_tip_outlined),
          title: const Text('Privacy Policy'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal?tab=privacy'),
        ),
      );
}

// ─────────────────────────────────────────────
// Terms of Service tile
// ─────────────────────────────────────────────

class _TermsOfServiceTile extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.gavel_outlined),
          title: const Text('Terms of Service'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/legal?tab=terms'),
        ),
      );
}

// ─────────────────────────────────────────────
// Export my data tile
// ─────────────────────────────────────────────

class _ExportDataTile extends StatefulWidget {
  const _ExportDataTile({required this.uid});
  final String uid;

  @override
  State<_ExportDataTile> createState() => _ExportDataTileState();
}

class _ExportDataTileState extends State<_ExportDataTile> {
  bool _busy = false;

  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final projects = await sl<ProjectService>()
          .projectsForOwner(widget.uid)
          .first;
      final file = await sl<CsvService>().exportUserData(widget.uid, projects);
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'BuildWise data export',
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: _busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.download_outlined),
        title: const Text('Export my data'),
        subtitle: const Text('Download all your project data as CSV'),
        trailing: _busy ? null : const Icon(Icons.chevron_right),
        onTap: _busy ? null : _export,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Switch role tile
// ─────────────────────────────────────────────

class _SwitchRoleTile extends StatelessWidget {
  const _SwitchRoleTile({required this.auth});
  final AuthService auth;

  @override
  Widget build(BuildContext context) {
    final currentRole = auth.currentUser?.role ?? UserRole.owner;
    // Admins cannot switch role via this tile
    if (currentRole == UserRole.admin) return const SizedBox.shrink();

    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz_outlined),
        title: const Text('Switch role'),
        subtitle: Text(
          currentRole == UserRole.owner
              ? 'Current: Property Owner — switch to Builder / PM'
              : 'Current: Builder / PM — switch to Property Owner',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showRoleSheet(context),
      ),
    );
  }

  void _showRoleSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RoleSwitchSheet(auth: auth),
    );
  }
}

class _RoleSwitchSheet extends StatefulWidget {
  const _RoleSwitchSheet({required this.auth});
  final AuthService auth;

  @override
  State<_RoleSwitchSheet> createState() => _RoleSwitchSheetState();
}

class _RoleSwitchSheetState extends State<_RoleSwitchSheet> {
  UserRole? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.auth.currentUser?.role ?? UserRole.owner;
  }

  Future<void> _confirm() async {
    if (_selected == null ||
        _selected == widget.auth.currentUser?.role) {
      Navigator.of(context).pop();
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Switch role?'),
        content: Text(
          'Your account will be switched to ${_selected!.label}. '
          'You can switch back at any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Switch'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.auth.updateRole(_selected!);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not switch role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final current = widget.auth.currentUser?.role ?? UserRole.owner;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Switch role',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'Your role determines which features are available to you.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          _RoleCard(
            title: 'Property Owner',
            subtitle: 'Create projects, hire builders, track costs',
            icon: Icons.home_outlined,
            selected: _selected == UserRole.owner,
            isCurrent: current == UserRole.owner,
            onTap: () => setState(() => _selected = UserRole.owner),
          ),
          const SizedBox(height: 12),
          _RoleCard(
            title: 'Builder / PM / Architect',
            subtitle: 'Manage builds, respond to contracts and quotes',
            icon: Icons.engineering_outlined,
            selected: _selected == UserRole.pm,
            isCurrent: current == UserRole.pm,
            onTap: () => setState(() => _selected = UserRole.pm),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _confirm,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.isCurrent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final bool isCurrent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? cs.primary : cs.outlineVariant,
            width: selected ? 2 : 1,
          ),
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.4)
              : cs.surface,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? cs.primary : cs.onSurfaceVariant,
              size: 28,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: selected ? cs.primary : null,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: 8),
                        Chip(
                          label: const Text('Current'),
                          visualDensity: VisualDensity.compact,
                          labelStyle: TextStyle(
                            fontSize: 10,
                            color: cs.onSecondaryContainer,
                          ),
                          backgroundColor: cs.secondaryContainer,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, color: cs.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 2),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
