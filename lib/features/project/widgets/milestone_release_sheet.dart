import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/builder_contract.dart';
import '../../../core/services/contract_service.dart';
import '../../../core/config/service_locator.dart';

/// Bottom sheet shown when a project owner taps "Release" on a milestone.
/// Displays fee breakdown and requires explicit confirmation before calling
/// [ContractService.releaseMilestonePayment].
class MilestoneReleaseSheet extends StatefulWidget {
  const MilestoneReleaseSheet({
    super.key,
    required this.contract,
    required this.milestone,
    required this.releasedByName,
  });

  final BuilderContract contract;
  final PaymentMilestone milestone;
  final String releasedByName;

  /// Opens the sheet. Returns [true] if the milestone was successfully released.
  static Future<bool?> show(
    BuildContext context, {
    required BuilderContract contract,
    required PaymentMilestone milestone,
    required String releasedByName,
  }) =>
      showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => MilestoneReleaseSheet(
          contract: contract,
          milestone: milestone,
          releasedByName: releasedByName,
        ),
      );

  @override
  State<MilestoneReleaseSheet> createState() => _MilestoneReleaseSheetState();
}

class _MilestoneReleaseSheetState extends State<MilestoneReleaseSheet> {
  bool _loading = false;
  static const double _platformFeePct = 0.02; // 2 %

  Future<void> _confirm() async {
    setState(() => _loading = true);
    try {
      await sl<ContractService>().releaseMilestonePayment(
        widget.contract.id,
        widget.milestone.id,
        widget.releasedByName,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop(true);
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Payment recorded. Automated disbursement will be available '
              'once our payment partner is connected.',
            ),
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to release: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = NumberFormat('#,##0.00');
    final m = widget.milestone;
    final fee = m.amountGhs * _platformFeePct;
    final netToBuilder = m.amountGhs - fee;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'Release Payment',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            m.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.outline,
                ),
          ),
          const SizedBox(height: 24),

          // Fee breakdown card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _Row('Milestone amount', 'GHS ${fmt.format(m.amountGhs)}'),
                const SizedBox(height: 8),
                _Row(
                  'Platform fee (2%)',
                  '− GHS ${fmt.format(fee)}',
                  valueColor: cs.error,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 0),
                ),
                _Row(
                  'To ${widget.contract.builderName}',
                  'GHS ${fmt.format(netToBuilder)}',
                  bold: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // PSP notice chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: cs.onSecondaryContainer,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Automated disbursement coming soon. Funds will be '
                    'transferred once our payment partner is connected.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSecondaryContainer,
                        ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _loading ? null : _confirm,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Confirm Release'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.valueColor});

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          fontWeight: bold ? FontWeight.w700 : null,
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: style),
        Text(
          value,
          style: style?.copyWith(color: valueColor),
        ),
      ],
    );
  }
}
