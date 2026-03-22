// lib/features/project/join_project_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/config/service_locator.dart';
import '../../core/errors/app_exception.dart';
import '../../core/models/invitation.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/invitation_service.dart';

class JoinProjectPage extends StatefulWidget {
  const JoinProjectPage({super.key, required this.token});

  final String token;

  @override
  State<JoinProjectPage> createState() => _JoinProjectPageState();
}

class _JoinProjectPageState extends State<JoinProjectPage> {
  final _tokenCtrl = TextEditingController();
  String? _activeToken;
  Invitation? _invitation;
  bool _loading = false;
  bool _acting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.token.isNotEmpty) {
      _activeToken = widget.token;
      _loadInvitation(widget.token);
    }
  }

  @override
  void dispose() {
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInvitation(String token) async {
    setState(() {
      _loading = true;
      _error = null;
      _invitation = null;
    });
    try {
      final inv = await sl<InvitationService>().fetchInvitation(token);
      setState(() {
        _invitation = inv;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Could not load invitation. Please check the link.';
        _loading = false;
      });
    }
  }

  Future<void> _accept() async {
    final user = sl<AuthService>().currentUser;
    if (user == null) {
      context.push('/sign-in');
      return;
    }
    setState(() => _acting = true);
    try {
      await sl<InvitationService>().acceptInvitation(
        _activeToken!,
        user.uid,
        user.displayName.isNotEmpty ? user.displayName : user.email,
        avatarUrl: user.photoUrl,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'You joined ${_invitation?.projectTitle ?? 'the project'}!',
            ),
          ),
        );
        context.go('/projects/${_invitation!.projectId}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }

  Future<void> _decline() async {
    setState(() => _acting = true);
    try {
      await sl<InvitationService>().declineInvitation(_activeToken!);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        setState(() => _acting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Project')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _activeToken == null
              ? _buildTokenEntry(cs, tt)
              : _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? _buildError(cs, tt)
                      : _invitation == null
                          ? _buildNotFound(tt)
                          : _buildInvitationCard(cs, tt),
        ),
      ),
    );
  }

  Widget _buildTokenEntry(ColorScheme cs, TextTheme tt) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 32),
        Icon(Icons.group_add_outlined, size: 64, color: cs.primary),
        const SizedBox(height: 16),
        Text(
          'Join a Project',
          style: tt.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'Enter the invitation token you received.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _tokenCtrl,
          decoration: const InputDecoration(
            labelText: 'Invitation token',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.key_outlined),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () {
            final t = _tokenCtrl.text.trim();
            if (t.isEmpty) return;
            setState(() => _activeToken = t);
            _loadInvitation(t);
          },
          child: const Text('Look up invitation'),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme cs, TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 64, color: cs.error),
          const SizedBox(height: 16),
          Text(_error ?? 'Something went wrong', style: tt.bodyLarge),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => setState(() {
              _activeToken = null;
              _error = null;
            }),
            child: const Text('Try another token'),
          ),
        ],
      ),
    );
  }

  Widget _buildNotFound(TextTheme tt) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.link_off, size: 64),
          const SizedBox(height: 16),
          Text(
            'Invitation not found',
            style: tt.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This invitation link is invalid or has been cancelled.',
            style: tt.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInvitationCard(ColorScheme cs, TextTheme tt) {
    final inv = _invitation!;

    if (inv.status != InvitationStatus.pending || inv.isExpired) {
      final message = inv.isExpired
          ? 'This invitation expired on ${DateFormat.yMMMd().format(inv.expiresAt)}.'
          : switch (inv.status) {
              InvitationStatus.accepted => 'This invitation has already been accepted.',
              InvitationStatus.declined => 'This invitation was declined.',
              InvitationStatus.cancelled => 'This invitation has been cancelled.',
              _ => 'This invitation is no longer valid.',
            };

      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.do_not_disturb_outlined, size: 64, color: cs.error),
            const SizedBox(height: 16),
            Text(message, style: tt.bodyLarge, textAlign: TextAlign.center),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.construction_outlined, color: cs.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        inv.projectTitle,
                        style: tt.titleLarge,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                _InfoRow(label: 'Invited by', value: inv.inviterName),
                const SizedBox(height: 8),
                _InfoRow(label: 'Role', value: _formatRole(inv.role)),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Access level',
                  value: inv.permissionTier == 'observer'
                      ? 'Observer (read + chat)'
                      : 'Collaborator (full write access)',
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  label: 'Expires',
                  value: DateFormat.yMMMd().format(inv.expiresAt),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (_acting)
          const Center(child: CircularProgressIndicator())
        else ...[
          FilledButton.icon(
            onPressed: _accept,
            icon: const Icon(Icons.check),
            label: const Text('Accept & join project'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: _decline,
            style: OutlinedButton.styleFrom(
              foregroundColor: cs.error,
              side: BorderSide(color: cs.error),
            ),
            child: const Text('Decline'),
          ),
        ],
      ],
    );
  }

  String _formatRole(String role) {
    return switch (role) {
      'pm' => 'Project Manager',
      'contractor' => 'Contractor',
      'architect' => 'Architect',
      'engineer' => 'Engineer',
      'inspector' => 'Inspector',
      'electrician' => 'Electrician',
      'plumber' => 'Plumber',
      _ => 'Team Member',
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        Expanded(child: Text(value, style: tt.bodyMedium)),
      ],
    );
  }
}
