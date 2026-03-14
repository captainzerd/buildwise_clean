import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/rfq_request.dart';

/// Side-by-side comparison of vendor quotes for a project.
/// Only shows RFQs that have a response (responded, accepted, or declined).
class QuoteComparisonPage extends StatelessWidget {
  const QuoteComparisonPage({
    super.key,
    required this.projectTitle,
    required this.rfqs,
  });

  final String projectTitle;
  final List<RfqRequest> rfqs;

  @override
  Widget build(BuildContext context) {
    final responded = rfqs
        .where(
          (r) =>
              r.quotedAmountGhs != null &&
              r.status != RfqStatus.sent,
        )
        .toList()
      ..sort((a, b) {
        final aAmt = a.quotedAmountGhs ?? double.infinity;
        final bAmt = b.quotedAmountGhs ?? double.infinity;
        return aAmt.compareTo(bAmt);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Compare Quotes')),
      body: responded.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.compare_arrows_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(height: 16),
                  const Text('No responded quotes to compare.'),
                  const SizedBox(height: 8),
                  Text(
                    'Send quote requests to vendors and wait for responses.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    projectTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${responded.length} quote${responded.length == 1 ? '' : 's'} — sorted lowest to highest',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                  ),
                  const SizedBox(height: 16),
                  for (int i = 0; i < responded.length; i++)
                    _QuoteComparisonCard(
                      rfq: responded[i],
                      rank: i + 1,
                      isBest: i == 0,
                    ),
                ],
              ),
            ),
    );
  }
}

class _QuoteComparisonCard extends StatelessWidget {
  const _QuoteComparisonCard({
    required this.rfq,
    required this.rank,
    required this.isBest,
  });
  final RfqRequest rfq;
  final int rank;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: isBest
          ? RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: cs.primary, width: 2),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isBest
                  ? cs.primaryContainer
                  : cs.surfaceContainerHighest,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor:
                      isBest ? cs.primary : cs.outlineVariant,
                  child: Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isBest ? cs.onPrimary : cs.outline,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    rfq.vendorName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isBest ? cs.onPrimaryContainer : null,
                        ),
                  ),
                ),
                if (isBest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2,),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Lowest',
                      style: TextStyle(
                        fontSize: 10,
                        color: cs.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                _StatusBadge(status: rfq.status),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Amount
                if (rfq.quotedAmountGhs != null) ...[
                  Row(
                    children: [
                      const Icon(Icons.attach_money_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'GHS ${moneyFmt.format(rfq.quotedAmountGhs!)}',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              color: cs.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Description
                Text(
                  'Request',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
                Text(
                  rfq.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),

                // Response
                if (rfq.responseText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Vendor response',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                  Text(
                    rfq.responseText!,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 5,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                const SizedBox(height: 8),
                Row(
                  children: [
                    if (rfq.dueDate != null)
                      _MetaItem(
                        icon: Icons.calendar_today_outlined,
                        label: 'Due ${dateFmt.format(rfq.dueDate!)}',
                      ),
                    if (rfq.dueDate != null) const SizedBox(width: 12),
                    _MetaItem(
                      icon: Icons.send_outlined,
                      label: 'Sent ${dateFmt.format(rfq.createdAt)}',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
        ),
      ],
    );
  }
}
