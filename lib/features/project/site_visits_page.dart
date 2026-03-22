// lib/features/project/site_visits_page.dart
import 'package:flutter/material.dart';
import '../../core/errors/app_exception.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/site_visit.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/site_visit_service.dart';
import '../../core/widgets/empty_state.dart';

class SiteVisitsPage extends StatelessWidget {
  const SiteVisitsPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final service = context.watch<SiteVisitService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Inspections'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              projectTitle,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ),
      ),
      body: StreamBuilder<List<SiteVisit>>(
        stream: service.visitsStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final visits = snap.data ?? [];
          if (visits.isEmpty) {
            return const EmptyState(
              icon: Icons.location_city_outlined,
              title: 'No site inspections',
              message: 'Schedule a site visit to track on-site progress.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: visits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _VisitCard(
              visit: visits[i],
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Schedule Visit'),
        onPressed: () => _showScheduleSheet(context, auth, service),
      ),
    );
  }

  void _showScheduleSheet(
    BuildContext context,
    AuthService auth,
    SiteVisitService service,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ScheduleVisitSheet(
        projectId: projectId,
        schedulerUid: auth.currentUser?.uid ?? '',
        schedulerName: auth.currentUser?.displayName ?? 'User',
        service: service,
      ),
    );
  }
}

// ── Visit Card ─────────────────────────────────────────────────────────────────

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.visit, required this.service});

  final SiteVisit visit;
  final SiteVisitService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isPast = visit.scheduledAt.isBefore(DateTime.now());

    Color statusColor;
    switch (visit.status) {
      case VisitStatus.completed:
        statusColor = Colors.green;
      case VisitStatus.cancelled:
        statusColor = cs.outline;
      case VisitStatus.scheduled:
        statusColor = isPast ? Colors.orange : cs.primary;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.purpose,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(
                    visit.status == VisitStatus.scheduled && isPast
                        ? 'Overdue'
                        : visit.status.label,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  labelStyle: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                  side: BorderSide(color: statusColor),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today_outlined, size: 14, color: cs.outline),
                const SizedBox(width: 6),
                Text(
                  DateFormat('EEE d MMM yyyy, h:mm a').format(visit.scheduledAt),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.person_outline, size: 14, color: cs.outline),
                const SizedBox(width: 6),
                Text(
                  'Scheduled by ${visit.scheduledByName}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            if (visit.notes != null && visit.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  visit.notes!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (visit.status == VisitStatus.scheduled) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                      ),
                      onPressed: () => _cancel(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _markComplete(context),
                      child: const Text('Mark Complete'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _markComplete(BuildContext context) async {
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mark Visit as Complete'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            border: OutlineInputBorder(),
            hintText: 'Observations from the visit...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    notesCtrl.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      await service.markCompleted(
        visit.projectId,
        visit.id,
        notes: notesCtrl.text.trim(),
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Visit marked as completed')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)));
      }
    }
  }

  Future<void> _cancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Site Visit?'),
        content: const Text('This visit will be marked as cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel Visit'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await service.cancelVisit(visit.projectId, visit.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)));
      }
    }
  }
}

// ── Schedule Visit Sheet ───────────────────────────────────────────────────────

class _ScheduleVisitSheet extends StatefulWidget {
  const _ScheduleVisitSheet({
    required this.projectId,
    required this.schedulerUid,
    required this.schedulerName,
    required this.service,
  });

  final String projectId;
  final String schedulerUid;
  final String schedulerName;
  final SiteVisitService service;

  @override
  State<_ScheduleVisitSheet> createState() => _ScheduleVisitSheetState();
}

class _ScheduleVisitSheetState extends State<_ScheduleVisitSheet> {
  final _formKey = GlobalKey<FormState>();
  final _purposeCtrl = TextEditingController();
  DateTime _scheduledAt = DateTime.now().add(const Duration(days: 1));
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  bool _saving = false;

  @override
  void dispose() {
    _purposeCtrl.dispose();
    super.dispose();
  }

  DateTime get _combined => DateTime(
        _scheduledAt.year,
        _scheduledAt.month,
        _scheduledAt.day,
        _time.hour,
        _time.minute,
      );

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _scheduledAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
    );
    if (picked != null) setState(() => _scheduledAt = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.scheduleVisit(
        SiteVisit(
          id: '',
          projectId: widget.projectId,
          scheduledByUid: widget.schedulerUid,
          scheduledByName: widget.schedulerName,
          scheduledAt: _combined,
          purpose: _purposeCtrl.text.trim(),
          status: VisitStatus.scheduled,
          createdAt: DateTime.now(),
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Site visit scheduled')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM yyyy');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule Site Inspection',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _purposeCtrl,
              decoration: const InputDecoration(
                labelText: 'Purpose',
                border: OutlineInputBorder(),
                hintText: 'e.g. Foundation inspection, Plumbing review...',
              ),
              enabled: !_saving,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(fmt.format(_scheduledAt)),
                    onPressed: _saving ? null : _pickDate,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.access_time_outlined, size: 18),
                    label: Text(_time.format(context)),
                    onPressed: _saving ? null : _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Schedule'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
