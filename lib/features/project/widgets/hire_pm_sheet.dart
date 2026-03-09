// lib/features/project/widgets/hire_pm_sheet.dart
import 'package:flutter/material.dart';

import '../../../core/config/service_locator.dart';
import '../../../core/models/pm_profile.dart';
import '../../../core/models/project.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/project_service.dart';

class HirePmSheet extends StatefulWidget {
  const HirePmSheet({
    super.key,
    required this.pm,
    required this.project,
  });

  final PmProfile pm;
  final Project project;

  @override
  State<HirePmSheet> createState() => _HirePmSheetState();
}

class _HirePmSheetState extends State<HirePmSheet> {
  bool _saving = false;

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    try {
      await sl<ProjectService>().assignPm(
        widget.project.id,
        pmUid: widget.pm.uid,
        pmName: widget.pm.displayName,
      );
      // Notify the PM via notification service inbox
      await sl<NotificationService>().createNotification(
        uid: widget.pm.uid,
        title: 'You have been assigned to a project',
        body:
            'You have been assigned as Project Manager for "${widget.project.title}".',
        type: 'pm_assigned',
        data: {'projectId': widget.project.id},
      );
      nav.pop(true); // true = success
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(
          content: Text('Failed to assign PM: $e'),
          duration: const Duration(seconds: 10),
        ),);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pm = widget.pm;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Assign Project Manager',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: cs.primaryContainer,
              child: Text(
                pm.displayName.isNotEmpty
                    ? pm.displayName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: cs.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(pm.displayName),
            subtitle: Text(pm.role.label),
          ),
          const SizedBox(height: 8),
          Text(
            'Assign ${pm.displayName} as Project Manager for '
            '"${widget.project.title}"?\n\n'
            'They will be able to view and manage this project.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _confirm,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm Assignment'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _saving ? null : () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }
}
