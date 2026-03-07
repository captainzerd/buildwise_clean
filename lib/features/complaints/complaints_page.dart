import '../../core/config/service_locator.dart';
// lib/features/complaints/complaints_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/complaint.dart';
import '../../core/models/project.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/complaint_service.dart';
import '../../core/services/project_service.dart';

class ComplaintsPage extends StatelessWidget {
  const ComplaintsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final service = sl<ComplaintService>();
    final uid = auth.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Complaints')),
      body: StreamBuilder<List<Complaint>>(
        stream: service.listForUser(uid),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final complaints = snap.data!;
          if (complaints.isEmpty) {
            return const _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: complaints.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ComplaintCard(
              complaint: complaints[i],
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('New complaint'),
        onPressed: () => _showSubmitSheet(context, service, uid),
      ),
    );
  }

  void _showSubmitSheet(
    BuildContext context,
    ComplaintService service,
    String uid,
  ) {
    final projectService = sl<ProjectService>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubmitComplaintSheet(
        service: service,
        uid: uid,
        projectService: projectService,
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Complaint card
// ─────────────────────────────────────────────

class _ComplaintCard extends StatelessWidget {
  const _ComplaintCard({required this.complaint, required this.service});
  final Complaint complaint;
  final ComplaintService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complaint.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: complaint.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule_outlined,
                    size: 13, color: cs.outline,),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM yyyy').format(complaint.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
                if (complaint.projectId != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.work_outline, size: 13, color: cs.outline),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      complaint.projectTitle ?? 'Project linked',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: cs.outline),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                const Spacer(),
                if (complaint.status == 'open')
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      visualDensity: VisualDensity.compact,
                    ),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Delete'),
                    onPressed: () => _confirmDelete(context),
                  ),
              ],
            ),
            if (complaint.adminResponse != null &&
                complaint.adminResponse!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: cs.secondaryContainer.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.support_agent_outlined,
                      size: 16,
                      color: cs.secondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'WyseBrix team',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: cs.secondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            complaint.adminResponse!,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete complaint?'),
        content: const Text('This complaint will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await service.delete(complaint.id);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 10)),
          );
        }
      }
    }
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (Color bg, Color fg, String label) = switch (status) {
      'in_progress' => (
          cs.tertiaryContainer,
          cs.onTertiaryContainer,
          'In progress',
        ),
      'closed' => (
          cs.surfaceContainerHighest,
          cs.outline,
          'Closed',
        ),
      _ => (cs.errorContainer, cs.onErrorContainer, 'Open'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w500),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Submit complaint sheet
// ─────────────────────────────────────────────

class _SubmitComplaintSheet extends StatefulWidget {
  const _SubmitComplaintSheet({
    required this.service,
    required this.uid,
    required this.projectService,
  });
  final ComplaintService service;
  final String uid;
  final ProjectService projectService;

  @override
  State<_SubmitComplaintSheet> createState() => _SubmitComplaintSheetState();
}

class _SubmitComplaintSheetState extends State<_SubmitComplaintSheet> {
  final _formKey = GlobalKey<FormState>();
  final _msgCtrl = TextEditingController();
  bool _saving = false;
  Project? _selectedProject;

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final complaint = Complaint(
        id: '',
        userUid: widget.uid,
        projectId: _selectedProject?.id,
        projectTitle: _selectedProject?.title,
        message: _msgCtrl.text.trim(),
        status: 'open',
        createdAt: DateTime.now(),
      );
      await widget.service.create(complaint);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), duration: const Duration(seconds: 10)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Submit a complaint',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              'Describe your issue and our team will review it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 16),

            // Optional project picker
            StreamBuilder<List<Project>>(
              stream: widget.projectService.projectsForOwner(widget.uid),
              builder: (ctx, snap) {
                final projects = snap.data ?? const [];
                if (projects.isEmpty) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<Project?>(
                    decoration: const InputDecoration(
                      labelText: 'Link to project (optional)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    initialValue: _selectedProject,
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('No project'),
                      ),
                      for (final p in projects)
                        DropdownMenuItem(
                          value: p,
                          child: Text(
                            p.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (p) => setState(() => _selectedProject = p),
                  ),
                );
              },
            ),

            TextFormField(
              controller: _msgCtrl,
              decoration: const InputDecoration(
                labelText: 'Message *',
                hintText: 'Describe the issue…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().length < 10)
                  ? 'Please write at least 10 characters'
                  : null,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_saving ? 'Submitting…' : 'Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'No complaints',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to report an issue.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
