// lib/features/notifications/notification_prefs_page.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/notification_service.dart';

class NotificationPrefsPage extends StatelessWidget {
  const NotificationPrefsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final svc = sl<NotificationService>();
    final uid = auth.currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Preferences')),
      body: StreamBuilder<Map<String, bool>>(
        stream: svc.prefsStream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    const Text(
                      'Could not load preferences.\nUsing defaults.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          final prefs = snap.data ?? Map<String, bool>.from(NotificationService.defaultPrefs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Choose which push notifications you receive. '
                'All activity is still visible in your notification inbox.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              _PrefsCard(
                prefs: prefs,
                uid: uid,
                svc: svc,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PrefsCard extends StatefulWidget {
  const _PrefsCard({
    required this.prefs,
    required this.uid,
    required this.svc,
  });

  final Map<String, bool> prefs;
  final String uid;
  final NotificationService svc;

  @override
  State<_PrefsCard> createState() => _PrefsCardState();
}

class _PrefsCardState extends State<_PrefsCard> {
  late Map<String, bool> _local;

  // Section definitions: title -> list of pref keys
  static const _sections = [
    (
      title: 'Project Activity',
      keys: ['project_updates', 'phase_changes', 'cost_entries', 'deletion_requests'],
    ),
    (
      title: 'Financial',
      keys: ['budget_alerts', 'change_orders'],
    ),
    (
      title: 'Team & Communication',
      keys: ['assignment', 'contracts', 'chat_messages', 'quote_responses', 'task_comments'],
    ),
    (
      title: 'Site Operations',
      keys: ['site_inspections', 'snag_list', 'issue_reports', 'safety_incidents'],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _local = Map<String, bool>.from(widget.prefs);
  }

  @override
  void didUpdateWidget(_PrefsCard old) {
    super.didUpdateWidget(old);
    if (old.prefs == widget.prefs) return;
    for (final k in widget.prefs.keys) {
      if (old.prefs[k] == _local[k]) {
        _local[k] = widget.prefs[k]!;
      }
    }
  }

  Future<void> _toggle(String key, bool value) async {
    setState(() => _local[key] = value);
    try {
      await widget.svc.savePrefs(widget.uid, _local);
    } catch (_) {
      if (mounted) setState(() => _local[key] = !value);
    }
  }

  Future<void> _toggleSection(List<String> keys, bool value) async {
    setState(() {
      for (final k in keys) {
        _local[k] = value;
      }
    });
    try {
      await widget.svc.savePrefs(widget.uid, _local);
    } catch (_) {
      if (mounted) {
        setState(() {
          for (final k in keys) {
            _local[k] = !value;
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final section in _sections) ...[
          _SectionHeader(
            title: section.title,
            keys: section.keys,
            local: _local,
            onToggleAll: (v) => _toggleSection(section.keys, v),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Column(
              children: [
                for (var i = 0; i < section.keys.length; i++) ...[
                  if (i > 0) const Divider(height: 0, indent: 56),
                  _PrefTile(
                    icon: _iconFor(section.keys[i]),
                    title: _titleFor(section.keys[i]),
                    subtitle: _subtitleFor(section.keys[i]),
                    value: _local[section.keys[i]] ?? true,
                    onChanged: (v) => _toggle(section.keys[i], v),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  IconData _iconFor(String key) => switch (key) {
        'project_updates' => Icons.newspaper_outlined,
        'phase_changes' => Icons.layers_outlined,
        'cost_entries' => Icons.receipt_long_outlined,
        'deletion_requests' => Icons.delete_outline,
        'budget_alerts' => Icons.warning_amber_outlined,
        'change_orders' => Icons.change_circle_outlined,
        'assignment' => Icons.assignment_ind_outlined,
        'contracts' => Icons.handshake_outlined,
        'chat_messages' => Icons.forum_outlined,
        'quote_responses' => Icons.request_quote_outlined,
        'site_inspections' => Icons.location_city_outlined,
        'snag_list' => Icons.construction_outlined,
        'task_comments' => Icons.comment_outlined,
        'issue_reports' => Icons.report_problem_outlined,
        'safety_incidents' => Icons.warning_amber_outlined,
        _ => Icons.notifications_outlined,
      };

  String _titleFor(String key) => switch (key) {
        'project_updates' => 'Project updates',
        'phase_changes' => 'Phase changes',
        'cost_entries' => 'Cost entries',
        'deletion_requests' => 'Deletion requests',
        'budget_alerts' => 'Budget alerts',
        'change_orders' => 'Change orders',
        'assignment' => 'Project assignment',
        'contracts' => 'Contracts',
        'chat_messages' => 'Chat messages',
        'quote_responses' => 'Quote responses',
        'site_inspections' => 'Site inspections',
        'snag_list' => 'Snag list',
        'task_comments' => 'Task comments',
        'issue_reports' => 'Issue reports',
        'safety_incidents' => 'Safety incidents',
        _ => key,
      };

  String _subtitleFor(String key) => switch (key) {
        'project_updates' => 'When your builder posts a progress update',
        'phase_changes' => 'When a phase is added or its status changes',
        'cost_entries' => 'When your builder records a new cost',
        'deletion_requests' => 'Requests to delete costs or payments, and their resolution',
        'budget_alerts' => 'When project spend reaches your alert threshold',
        'change_orders' => 'When a variation order is submitted or decided',
        'assignment' => 'When you are assigned to a project as builder',
        'contracts' => 'When a contract is created or signed',
        'chat_messages' => 'When someone sends a message in your project chat',
        'quote_responses' => 'When a vendor responds to a quote request, or accepts/declines',
        'site_inspections' => 'When a site visit is scheduled',
        'snag_list' => 'When a new snag item is raised',
        'task_comments' => 'When someone comments on a task you are assigned to',
        'issue_reports' => 'When a new defect or quality issue is reported',
        'safety_incidents' => 'When a safety incident is reported on your project',
        _ => '',
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.keys,
    required this.local,
    required this.onToggleAll,
  });

  final String title;
  final List<String> keys;
  final Map<String, bool> local;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final allOn = keys.every((k) => local[k] == true);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const Spacer(),
          Text(
            'All',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 4),
          Switch(
            value: allOn,
            onChanged: onToggleAll,
          ),
        ],
      ),
    );
  }
}

class _PrefTile extends StatelessWidget {
  const _PrefTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      secondary: Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      value: value,
      onChanged: onChanged,
    );
  }
}
