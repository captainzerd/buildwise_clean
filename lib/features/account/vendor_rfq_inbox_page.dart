import '../../core/config/service_locator.dart';
// lib/features/account/vendor_rfq_inbox_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/rfq_request.dart';
import '../../core/services/rfq_service.dart';

class VendorRfqInboxPage extends StatelessWidget {
  const VendorRfqInboxPage({super.key, required this.vendorId});

  final String vendorId;

  @override
  Widget build(BuildContext context) {
    final rfqService = sl<RfqService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Quote Requests')),
      body: StreamBuilder<List<RfqRequest>>(
        stream: rfqService.vendorRfqsStream(vendorId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final rfqs = snap.data ?? [];
          if (rfqs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.inbox_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No quote requests yet',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rfqs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _InboxRfqCard(
              rfq: rfqs[i],
              onRespond: () => _showRespondSheet(context, rfqs[i], rfqService),
            ),
          );
        },
      ),
    );
  }

  void _showRespondSheet(
    BuildContext context,
    RfqRequest rfq,
    RfqService rfqService,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _RespondSheet(rfq: rfq, rfqService: rfqService),
    );
  }
}

class _InboxRfqCard extends StatelessWidget {
  const _InboxRfqCard({required this.rfq, required this.onRespond});
  final RfqRequest rfq;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final dateFmt = DateFormat('d MMM yyyy');
    final moneyFmt = NumberFormat('#,##0.00');
    final isPending = rfq.status == RfqStatus.sent;

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
                    rfq.projectTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _StatusChip(status: rfq.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rfq.description,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (rfq.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Due by ${dateFmt.format(rfq.dueDate!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: rfq.dueDate!.isBefore(DateTime.now()) &&
                              isPending
                          ? cs.error
                          : cs.outline,
                    ),
              ),
            ],
            if (rfq.responseText != null) ...[
              const Divider(height: 16),
              Text(
                'Your response:',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                rfq.responseText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (rfq.quotedAmountGhs != null)
                Text(
                  'Quoted: GHS ${moneyFmt.format(rfq.quotedAmountGhs!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: onRespond,
                  child: const Text('Respond'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RespondSheet extends StatefulWidget {
  const _RespondSheet({required this.rfq, required this.rfqService});
  final RfqRequest rfq;
  final RfqService rfqService;

  @override
  State<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends State<_RespondSheet> {
  final _responseCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _responseCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_responseCtrl.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.rfqService.respondToRfq(
        widget.rfq.id,
        responseText: _responseCtrl.text.trim(),
        quotedAmountGhs: double.tryParse(_amountCtrl.text),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Respond to Quote Request',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            widget.rfq.projectTitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
          ),
          const SizedBox(height: 16),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ),
          TextField(
            controller: _responseCtrl,
            decoration: const InputDecoration(
              labelText: 'Your response *',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            autofocus: true,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amountCtrl,
            decoration: const InputDecoration(
              labelText: 'Quoted amount (GHS, optional)',
              prefixText: 'GH₵ ',
              border: OutlineInputBorder(),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _send,
              child: Text(_saving ? 'Sending…' : 'Send Response'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final RfqStatus status;

  @override
  Widget build(BuildContext context) {
    final (color, bg) = switch (status) {
      RfqStatus.sent => (Colors.blue, Colors.blue.shade50),
      RfqStatus.responded => (Colors.green, Colors.green.shade50),
      RfqStatus.accepted => (Colors.green.shade700, Colors.green.shade100),
      RfqStatus.declined => (Colors.red, Colors.red.shade50),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
