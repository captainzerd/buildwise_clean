import '../../core/config/service_locator.dart';
// lib/features/project/project_quotes_page.dart
import 'package:flutter/material.dart';
import '../../core/errors/app_exception.dart';
import 'package:intl/intl.dart';

import '../../core/models/rfq_request.dart';
import '../../core/services/rfq_service.dart';
import 'quote_comparison_page.dart';

class ProjectQuotesPage extends StatelessWidget {
  const ProjectQuotesPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
  });

  final String projectId;
  final String projectTitle;

  @override
  Widget build(BuildContext context) {
    final rfqService = sl<RfqService>();

    return Scaffold(
      appBar: AppBar(title: Text('Quotes — $projectTitle')),
      body: StreamBuilder<List<RfqRequest>>(
        stream: rfqService.ownerRfqsStream(projectId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final rfqs = snap.data ?? [];
          final respondedCount = rfqs
              .where(
                (r) =>
                    r.quotedAmountGhs != null && r.status != RfqStatus.sent,
              )
              .length;
          if (rfqs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.request_quote_outlined,
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
                  const SizedBox(height: 8),
                  Text(
                    "Open a vendor's profile to send a quote request.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          }
          return Column(
            children: [
              if (respondedCount >= 2)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonal(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => QuoteComparisonPage(
                            projectTitle: projectTitle,
                            rfqs: rfqs,
                          ),
                        ),
                      ),
                      child: Text('Compare $respondedCount Quotes'),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: rfqs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) =>
                      _RfqCard(rfq: rfqs[i], rfqService: rfqService),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RfqCard extends StatelessWidget {
  const _RfqCard({required this.rfq, required this.rfqService});
  final RfqRequest rfq;
  final RfqService rfqService;

  Future<void> _accept(BuildContext context) async {
    try {
      await rfqService.acceptRfq(rfq.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote accepted')),
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

  Future<void> _decline(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Decline quote?'),
        content: const Text('Are you sure you want to decline this quote?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await rfqService.declineRfq(rfq.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Quote declined')),
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');

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
                    rfq.vendorName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _StatusChip(status: rfq.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rfq.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (rfq.dueDate != null) ...[
              const SizedBox(height: 4),
              Text(
                'Due by ${dateFmt.format(rfq.dueDate!)}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
            ],
            if (rfq.responseText != null) ...[
              const Divider(height: 16),
              Text(
                'Response:',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: cs.outline,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                rfq.responseText!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (rfq.quotedAmountGhs != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Quoted: GHS ${moneyFmt.format(rfq.quotedAmountGhs!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.primary,
                      ),
                ),
              ],
            ] else ...[
              const SizedBox(height: 4),
              Text(
                'Awaiting response',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.outline,
                      fontStyle: FontStyle.italic,
                    ),
              ),
            ],
            if (rfq.status == RfqStatus.responded) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.tonal(
                    onPressed: () => _accept(context),
                    child: const Text('Accept'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                    ),
                    onPressed: () => _decline(context),
                    child: const Text('Decline'),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Sent ${DateFormat('d MMM yyyy').format(rfq.createdAt)}',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                  ),
            ),
          ],
        ),
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
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
