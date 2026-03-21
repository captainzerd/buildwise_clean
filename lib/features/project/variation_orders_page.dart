// lib/features/project/variation_orders_page.dart
import 'package:flutter/material.dart';
import '../../core/errors/app_exception.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/app_user.dart';
import '../../core/models/variation_order.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/variation_order_service.dart';
import '../../core/widgets/empty_state.dart';

class VariationOrdersPage extends StatelessWidget {
  const VariationOrdersPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    this.projectBudgetGhs = 0.0,
  });

  final String projectId;
  final String projectTitle;
  final double projectBudgetGhs;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final service = context.watch<VariationOrderService>();
    final isOwner = auth.role.isClient;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Change Orders'),
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
      body: StreamBuilder<List<VariationOrder>>(
        stream: service.ordersStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snap.data ?? [];
          if (orders.isEmpty) {
            return const EmptyState(
              icon: Icons.change_circle_outlined,
              title: 'No change orders',
              message:
                  'Builders can submit variation orders for scope changes or cost adjustments.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _VoCard(
              order: orders[i],
              isOwner: isOwner,
              service: service,
            ),
          );
        },
      ),
      floatingActionButton: !isOwner
          ? FloatingActionButton.extended(
              key: const Key('add_variation_order_button'),
              icon: const Icon(Icons.add),
              label: const Text('Submit Change Order'),
              onPressed: () => _showSubmitSheet(context, auth, service),
            )
          : null,
    );
  }

  void _showSubmitSheet(
    BuildContext context,
    AuthService auth,
    VariationOrderService service,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _SubmitVoSheet(
        projectId: projectId,
        projectBudgetGhs: projectBudgetGhs,
        submitterUid: auth.currentUser?.uid ?? '',
        submitterName: auth.currentUser?.displayName ?? 'Builder',
        service: service,
      ),
    );
  }
}

// ── VO Card ────────────────────────────────────────────────────────────────────

class _VoCard extends StatelessWidget {
  const _VoCard({
    required this.order,
    required this.isOwner,
    required this.service,
  });

  final VariationOrder order;
  final bool isOwner;
  final VariationOrderService service;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    final isIncrease = order.costDeltaGhs >= 0;
    final deltaColor = isIncrease ? cs.error : Colors.green;

    Color statusColor;
    switch (order.status) {
      case VoStatus.approved:
        statusColor = Colors.green;
      case VoStatus.rejected:
        statusColor = cs.error;
      case VoStatus.pending:
        statusColor = cs.secondary;
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
                    order.title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Chip(
                  label: Text(order.status.label),
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
            Text(
              order.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  isIncrease
                      ? Icons.arrow_upward_rounded
                      : Icons.arrow_downward_rounded,
                  size: 16,
                  color: deltaColor,
                ),
                const SizedBox(width: 4),
                Text(
                  'GHS ${fmt.format(order.costDeltaGhs.abs())} ${isIncrease ? 'increase' : 'saving'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: deltaColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  'By ${order.submittedByName}',
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: cs.outline),
                ),
              ],
            ),
            if (order.approverComment != null &&
                order.approverComment!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Note: ${order.approverComment}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            Text(
              DateFormat('d MMM yyyy').format(order.createdAt),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: cs.outline),
            ),
            // ── Action buttons ───────────────────────────────────────────
            if (order.status == VoStatus.pending && isOwner) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error),
                      ),
                      onPressed: () => _decide(context, approved: false),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _decide(context, approved: true),
                      child: const Text('Approve'),
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

  Future<void> _decide(BuildContext context, {required bool approved}) async {
    final commentCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(approved ? 'Approve Change Order?' : 'Reject Change Order?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              approved
                  ? 'Approve "${order.title}"?'
                  : 'Reject "${order.title}"?',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: commentCtrl,
              decoration: const InputDecoration(
                labelText: 'Comment (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(approved ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );

    commentCtrl.dispose();
    if (confirmed != true || !context.mounted) return;

    try {
      if (approved) {
        await service.approveOrder(
          order.projectId,
          order.id,
          comment: commentCtrl.text.trim(),
        );
      } else {
        await service.rejectOrder(
          order.projectId,
          order.id,
          comment: commentCtrl.text.trim(),
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved ? 'Change order approved' : 'Change order rejected',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)),
        );
      }
    }
  }
}

// ── Submit VO Sheet ────────────────────────────────────────────────────────────

class _SubmitVoSheet extends StatefulWidget {
  const _SubmitVoSheet({
    required this.projectId,
    required this.projectBudgetGhs,
    required this.submitterUid,
    required this.submitterName,
    required this.service,
  });

  final String projectId;
  final double projectBudgetGhs;
  final String submitterUid;
  final String submitterName;
  final VariationOrderService service;

  @override
  State<_SubmitVoSheet> createState() => _SubmitVoSheetState();
}

class _SubmitVoSheetState extends State<_SubmitVoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _deltaCtrl = TextEditingController();
  bool _isIncrease = true;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _deltaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final raw = double.tryParse(_deltaCtrl.text.trim()) ?? 0;
    final delta = _isIncrease ? raw : -raw;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.service.submitOrder(
        VariationOrder(
          id: '',
          projectId: widget.projectId,
          submittedByUid: widget.submitterUid,
          submittedByName: widget.submitterName,
          title: _titleCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          costDeltaGhs: delta,
          status: VoStatus.pending,
          createdAt: DateTime.now(),
          projectBudgetGhs: widget.projectBudgetGhs,
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Change order submitted')),
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
              'Submit Change Order',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            TextFormField(
              key: const Key('vo_title_field'),
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
                hintText: 'e.g. Additional drainage works',
              ),
              enabled: !_saving,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Describe the scope change and reason...',
              ),
              enabled: !_saving,
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    key: const Key('vo_amount_field'),
                    controller: _deltaCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Amount (GHS)',
                      border: OutlineInputBorder(),
                      prefixText: 'GHS ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    enabled: !_saving,
                    validator: (v) {
                      final val = double.tryParse(v?.trim() ?? '');
                      if (val == null || val <= 0) return 'Enter a positive amount';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    const Text('Type'),
                    const SizedBox(height: 4),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(
                          value: true,
                          label: Text('Add'),
                          icon: Icon(Icons.add, size: 16),
                        ),
                        ButtonSegment(
                          value: false,
                          label: Text('Save'),
                          icon: Icon(Icons.remove, size: 16),
                        ),
                      ],
                      selected: {_isIncrease},
                      onSelectionChanged: _saving
                          ? null
                          : (s) => setState(() => _isIncrease = s.first),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('vo_save_button'),
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit for Approval'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
