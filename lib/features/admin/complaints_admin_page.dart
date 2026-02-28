// lib/features/admin/complaints_admin_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/complaint.dart';
import '../../core/services/complaint_service.dart';

class ComplaintsAdminPage extends StatelessWidget {
  const ComplaintsAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.read<ComplaintService>();

    return Scaffold(
      appBar: AppBar(title: const Text('All Complaints')),
      body: StreamBuilder<List<Complaint>>(
        stream: service.listAll(),
        builder: (ctx, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final complaints = snap.data!;
          if (complaints.isEmpty) {
            return const Center(child: Text('No complaints yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: complaints.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) =>
                _ComplaintAdminCard(complaint: complaints[i], service: service),
          );
        },
      ),
    );
  }
}

class _ComplaintAdminCard extends StatefulWidget {
  const _ComplaintAdminCard({
    required this.complaint,
    required this.service,
  });

  final Complaint complaint;
  final ComplaintService service;

  @override
  State<_ComplaintAdminCard> createState() => _ComplaintAdminCardState();
}

class _ComplaintAdminCardState extends State<_ComplaintAdminCard> {
  late final TextEditingController _responseCtrl;
  bool _savingResponse = false;

  @override
  void initState() {
    super.initState();
    _responseCtrl = TextEditingController(
      text: widget.complaint.adminResponse ?? '',
    );
  }

  @override
  void didUpdateWidget(_ComplaintAdminCard old) {
    super.didUpdateWidget(old);
    if (old.complaint.adminResponse != widget.complaint.adminResponse) {
      _responseCtrl.text = widget.complaint.adminResponse ?? '';
    }
  }

  @override
  void dispose() {
    _responseCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveResponse() async {
    setState(() => _savingResponse = true);
    try {
      await widget.service.updateResponse(
        widget.complaint.id,
        _responseCtrl.text,
      );
    } finally {
      if (mounted) setState(() => _savingResponse = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message
            Text(
              widget.complaint.message,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 10),

            // Meta row
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Text(
                  DateFormat('d MMM yyyy HH:mm').format(widget.complaint.createdAt),
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
                const SizedBox(width: 12),
                Icon(Icons.person_outline, size: 13, color: cs.outline),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.complaint.userUid,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: cs.outline),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Status + delete row
            Row(
              children: [
                const Text('Status: '),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: widget.complaint.status,
                  isDense: true,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 'open', child: Text('Open')),
                    DropdownMenuItem(
                      value: 'in_progress',
                      child: Text('In progress'),
                    ),
                    DropdownMenuItem(value: 'closed', child: Text('Closed')),
                  ],
                  onChanged: (v) {
                    if (v != null && v != widget.complaint.status) {
                      widget.service.updateStatus(widget.complaint.id, v);
                    }
                  },
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: cs.error),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context),
                ),
              ],
            ),

            const Divider(height: 20),

            // Admin response field
            Text(
              'Admin response',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.outline),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _responseCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter a response visible to the user…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: _savingResponse ? null : _saveResponse,
                child: Text(_savingResponse ? 'Saving…' : 'Save response'),
              ),
            ),
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
        content: const Text('This will permanently remove the complaint.'),
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
      await widget.service.delete(widget.complaint.id);
    }
  }
}
