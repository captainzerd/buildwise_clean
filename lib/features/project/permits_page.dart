// lib/features/project/permits_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/permit.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/permit_service.dart';
import 'da_contacts_page.dart';

final _dateFmt = DateFormat('dd MMM yyyy');

class PermitsPage extends StatelessWidget {
  const PermitsPage({super.key, required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context) {
    final permitService = sl<PermitService>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permits & Approvals'),
        actions: [
          IconButton(
            tooltip: 'DA Contact Directory',
            icon: const Icon(Icons.contacts_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const DaContactsPage(),
              ),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<PermitItem>>(
        stream: permitService.permitsStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final permits = snap.data ?? [];
          if (permits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.approval_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No permits yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Tap + to add your first permit application.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            itemCount: permits.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _PermitCard(
              permit: permits[i],
              projectId: projectId,
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Add Permit',
        onPressed: () => _showAddPermitSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Permit'),
      ),
    );
  }

  void _showAddPermitSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddPermitSheet(projectId: projectId),
    );
  }
}

// ── Permit Card ─────────────────────────────────────────────────────────────

class _PermitCard extends StatelessWidget {
  const _PermitCard({required this.permit, required this.projectId});

  final PermitItem permit;
  final String projectId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: Icon(
          _iconForType(permit.type),
          color: colorScheme.primary,
        ),
        title: Text(
          permit.type,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: _StatusChip(status: permit.status),
        ),
        children: [
          if (permit.referenceNumber != null &&
              permit.referenceNumber!.isNotEmpty)
            _InfoRow(
              label: 'Reference',
              value: permit.referenceNumber!,
            ),
          if (permit.notes.isNotEmpty)
            _InfoRow(label: 'Notes', value: permit.notes),
          if (permit.submittedAt != null)
            _InfoRow(
              label: 'Submitted',
              value: _dateFmt.format(permit.submittedAt!),
            ),
          if (permit.approvedAt != null)
            _InfoRow(
              label: 'Approved',
              value: _dateFmt.format(permit.approvedAt!),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: () => _showUpdateStatusSheet(context),
              child: const Text('Update Status'),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) => switch (type) {
        'EPA Clearance' => Icons.eco_outlined,
        'Structural Approval' => Icons.foundation_outlined,
        'Utility Connection' => Icons.electrical_services_outlined,
        _ => Icons.approval_outlined,
      };

  void _showUpdateStatusSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _UpdateStatusSheet(
        permit: permit,
        projectId: projectId,
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final PermitStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: status.color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withAlpha(100)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: status.color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

// ── Add Permit Sheet ─────────────────────────────────────────────────────────

class _AddPermitSheet extends StatefulWidget {
  const _AddPermitSheet({required this.projectId});

  final String projectId;

  @override
  State<_AddPermitSheet> createState() => _AddPermitSheetState();
}

class _AddPermitSheetState extends State<_AddPermitSheet> {
  final _formKey = GlobalKey<FormState>();
  String _type = 'Building Permit';
  final _notesCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  bool _saving = false;

  static const _permitTypes = [
    'Building Permit',
    'EPA Clearance',
    'Structural Approval',
    'Utility Connection',
  ];

  @override
  void dispose() {
    _notesCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _formKey.currentState!.save();

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid ?? '';

    setState(() => _saving = true);
    try {
      final permit = PermitItem(
        id: '',
        type: _type,
        status: PermitStatus.notStarted,
        notes: _notesCtrl.text.trim(),
        referenceNumber: _refCtrl.text.trim().isEmpty
            ? null
            : _refCtrl.text.trim(),
        updatedAt: DateTime.now(),
        updatedBy: uid,
      );
      await sl<PermitService>().addPermit(widget.projectId, permit);
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Permit added')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error adding permit: $e'),
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Add Permit',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Permit Type',
                border: OutlineInputBorder(),
              ),
              items: _permitTypes
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _refCtrl,
              decoration: const InputDecoration(
                labelText: 'Reference Number (optional)',
                hintText: 'e.g. DA/ACC/2026/1234',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Add Permit'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Update Status Sheet ──────────────────────────────────────────────────────

class _UpdateStatusSheet extends StatefulWidget {
  const _UpdateStatusSheet({required this.permit, required this.projectId});

  final PermitItem permit;
  final String projectId;

  @override
  State<_UpdateStatusSheet> createState() => _UpdateStatusSheetState();
}

class _UpdateStatusSheetState extends State<_UpdateStatusSheet> {
  late PermitStatus _status;
  late final TextEditingController _refCtrl;
  late final TextEditingController _notesCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _status = widget.permit.status;
    _refCtrl = TextEditingController(text: widget.permit.referenceNumber ?? '');
    _notesCtrl = TextEditingController(text: widget.permit.notes);
  }

  @override
  void dispose() {
    _refCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid ?? '';

    setState(() => _saving = true);
    try {
      await sl<PermitService>().updateStatus(
        widget.projectId,
        widget.permit.id,
        status: _status,
        referenceNumber: _refCtrl.text.trim().isEmpty
            ? null
            : _refCtrl.text.trim(),
        notes: _notesCtrl.text.trim(),
        updatedByUid: uid,
      );
      if (!mounted) return;
      nav.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Permit updated')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error updating permit: $e'),
          duration: const Duration(seconds: 10),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Update Status — ${widget.permit.type}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<PermitStatus>(
            initialValue: _status,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
            ),
            items: PermitStatus.values
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(s.label),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _refCtrl,
            decoration: const InputDecoration(
              labelText: 'Reference Number (optional)',
              hintText: 'e.g. DA/ACC/2026/1234',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _notesCtrl,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _submit,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
