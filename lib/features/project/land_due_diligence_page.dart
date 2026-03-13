import '../../core/config/service_locator.dart';
// lib/features/project/land_due_diligence_page.dart
import '../../core/errors/app_exception.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models/due_diligence_item.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/due_diligence_service.dart';

class LandDueDiligencePage extends StatefulWidget {
  const LandDueDiligencePage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.isOwner,
  });

  final String projectId;
  final String projectTitle;
  final bool isOwner;

  @override
  State<LandDueDiligencePage> createState() => _LandDueDiligencePageState();
}

class _LandDueDiligencePageState extends State<LandDueDiligencePage> {
  late final DueDiligenceService _service;

  @override
  void initState() {
    super.initState();
    _service = sl<DueDiligenceService>();
    _service.seedDefaultItems(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Due Diligence — ${widget.projectTitle}'),
      ),
      body: StreamBuilder<List<DueDiligenceItem>>(
        stream: _service.itemsStream(widget.projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          final pending =
              items.where((i) => i.status == DueDiligenceStatus.pending).length;
          final verified = items
              .where((i) => i.status == DueDiligenceStatus.verified)
              .length;
          final failed =
              items.where((i) => i.status == DueDiligenceStatus.failed).length;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: _SummaryCard(
                    pending: pending,
                    verified: verified,
                    failed: failed,
                    total: items.length,
                  ),
                ),
              ),
              SliverList.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 0, indent: 16),
                itemBuilder: (_, i) => _DueDiligenceTile(
                  item: items[i],
                  isOwner: widget.isOwner,
                  onUpdate: (status, notes) => _update(
                    context,
                    items[i].id,
                    status,
                    notes,
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _update(
    BuildContext context,
    String itemId,
    DueDiligenceStatus status,
    String? notes,
  ) async {
    final auth = context.read<AuthService>();
    try {
      await _service.updateItem(
        widget.projectId,
        itemId,
        status: status,
        notes: notes,
        verifiedByName: auth.currentUser?.displayName,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)),
        );
      }
    }
  }
}

// ── Summary card ──────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.pending,
    required this.verified,
    required this.failed,
    required this.total,
  });

  final int pending;
  final int verified;
  final int failed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allClear = pending == 0 && failed == 0;

    return Card(
      color: allClear ? Colors.green.shade50 : cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              allClear ? Icons.verified_outlined : Icons.warning_amber_outlined,
              color: allClear ? Colors.green.shade700 : cs.onErrorContainer,
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    allClear
                        ? 'All checks passed'
                        : '$pending pending · $failed failed',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: allClear
                              ? Colors.green.shade700
                              : cs.onErrorContainer,
                        ),
                  ),
                  Text(
                    '$verified of $total items verified',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: allClear
                              ? Colors.green.shade600
                              : cs.onErrorContainer,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Item tile ─────────────────────────────────────────────────────────────────

class _DueDiligenceTile extends StatelessWidget {
  const _DueDiligenceTile({
    required this.item,
    required this.isOwner,
    required this.onUpdate,
  });

  final DueDiligenceItem item;
  final bool isOwner;
  final void Function(DueDiligenceStatus status, String? notes) onUpdate;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (icon, color) = switch (item.status) {
      DueDiligenceStatus.verified => (
          Icons.check_circle_outline,
          Colors.green.shade700
        ),
      DueDiligenceStatus.failed => (Icons.cancel_outlined, cs.error),
      _ => (Icons.radio_button_unchecked, cs.outline),
    };

    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(item.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.description,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (item.notes != null && item.notes!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Notes: ${item.notes}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
          if (item.verifiedAt != null) ...[
            const SizedBox(height: 2),
            Text(
              'Verified by ${item.verifiedByName ?? 'owner'} on '
              '${_fmt(item.verifiedAt!)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.green.shade600,
                  ),
            ),
          ],
        ],
      ),
      trailing: isOwner
          ? PopupMenuButton<DueDiligenceStatus>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (status) => _showUpdateDialog(context, status),
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: DueDiligenceStatus.verified,
                  child: ListTile(
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                    title: Text('Mark as Verified'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: DueDiligenceStatus.pending,
                  child: ListTile(
                    leading: Icon(Icons.radio_button_unchecked),
                    title: Text('Mark as Pending'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                const PopupMenuItem(
                  value: DueDiligenceStatus.failed,
                  child: ListTile(
                    leading: Icon(Icons.cancel_outlined, color: Colors.red),
                    title: Text('Mark as Failed'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _showUpdateDialog(
    BuildContext context,
    DueDiligenceStatus status,
  ) async {
    final notesCtrl = TextEditingController(text: item.notes ?? '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mark as ${status.label}'),
        content: TextField(
          controller: notesCtrl,
          decoration: const InputDecoration(
            labelText: 'Notes (optional)',
            hintText: 'e.g. Document received, reference number…',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Update'),
          ),
        ],
      ),
    );
    notesCtrl.dispose();
    if (confirmed == true) {
      onUpdate(
        status,
        notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
    }
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
