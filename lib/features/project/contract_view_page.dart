import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/builder_contract.dart';
import '../../core/services/contract_service.dart';
import '../contract/contract_sign_page.dart';
import 'widgets/milestone_release_sheet.dart';

class ContractViewPage extends StatefulWidget {
  const ContractViewPage({
    super.key,
    required this.contract,
    required this.currentUserUid,
    this.signerName = '',
  });

  final BuilderContract contract;
  final String currentUserUid;
  final String signerName;

  @override
  State<ContractViewPage> createState() => _ContractViewPageState();
}

class _ContractViewPageState extends State<ContractViewPage> {
  bool _busy = false;
  String? _error;

  bool get _isOwner => widget.currentUserUid == widget.contract.ownerUid;
  bool get _isBuilder => widget.currentUserUid == widget.contract.builderUid;

  Future<void> _decline() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Decline contract?'),
        content: const Text(
          'This will notify the owner that you have declined the contract.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Decline'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await sl<ContractService>().builderDecline(widget.contract.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel contract?'),
        content: const Text('This will cancel the pending contract request.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel contract'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await sl<ContractService>().ownerCancel(widget.contract.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Builder Contract',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              'The owner creates the contract with scope of work and payment milestones.',
              'The builder must sign (accept) before any milestone payments are released.',
              'Payment milestones are released by the owner after verifying phase completion.',
              'A retention % is held back until project completion to protect the owner.',
              'Once both parties have signed, the contract status becomes Active.',
              'To decline a contract, tap the Decline button — the owner will be notified.',
            ].map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final c = widget.contract;
    final fmt = DateFormat('d MMM yyyy');
    final fmtFull = DateFormat('d MMM yyyy, h:mm a');
    final moneyFmt = NumberFormat('#,##0.00');
    final isPending = c.status == ContractStatus.pendingBuilder;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Contract'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
          if (_isOwner && isPending)
            TextButton(
              onPressed: _busy ? null : _cancel,
              child: const Text('Cancel'),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          _StatusBanner(status: c.status),
          const SizedBox(height: 16),

          // Parties
          _SectionTitle('Parties'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const Text('Owner'),
                  subtitle: const Text('Project owner'),
                  trailing: c.ownerSignatureName.isNotEmpty
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 18,)
                      : null,
                ),
                const Divider(height: 0, indent: 56),
                ListTile(
                  leading: const Icon(Icons.engineering_outlined),
                  title: Text(c.builderName),
                  subtitle: const Text('Builder'),
                  trailing: c.builderSignatureName != null
                      ? const Icon(Icons.check_circle,
                          color: Colors.green, size: 18,)
                      : const Icon(Icons.pending_outlined,
                          color: Colors.orange, size: 18,),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Project
          _SectionTitle('Project'),
          _InfoRow('Project', c.projectTitle),
          if (c.startDate != null)
            _InfoRow('Start date', fmt.format(c.startDate!)),
          if (c.endDate != null)
            _InfoRow('End date', fmt.format(c.endDate!)),
          const SizedBox(height: 16),

          // Scope
          _SectionTitle('Scope of Work'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                c.scope,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Financials
          _SectionTitle('Payment'),
          _InfoRow(
            'Total contract value',
            'GHS ${moneyFmt.format(c.totalAmountGhs)}',
            bold: true,
          ),
          if (c.retentionPct > 0) ...[
            _InfoRow(
              'Retention (${c.retentionPct.toStringAsFixed(0)}%)',
              'GHS ${moneyFmt.format(c.retentionAmountGhs)}',
            ),
            _InfoRow(
              'Releasable',
              'GHS ${moneyFmt.format(c.amountReleasableGhs)}',
            ),
            if (c.retentionReleasedAt != null)
              _InfoRow(
                'Retention released',
                fmt.format(c.retentionReleasedAt!),
              )
            else if (_isOwner && c.status == ContractStatus.active)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: TextButton.icon(
                  icon: const Icon(Icons.lock_open_outlined, size: 16),
                  label: const Text('Release Retention'),
                  onPressed: () async {
                    await sl<ContractService>()
                        .releaseRetention(widget.contract.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Retention released')),
                      );
                    }
                  },
                ),
              ),
          ],
          if (c.milestones.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Payment Schedule',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.outline,
                  ),
            ),
            const SizedBox(height: 4),
            for (int i = 0; i < c.milestones.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Text(
                      '${i + 1}. ${c.milestones[i].description}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    Text(
                      'GHS ${moneyFmt.format(c.milestones[i].amountGhs)}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 16),

          const SizedBox(height: 16),

          // Milestone tracker
          _SectionTitle('Milestone Tracker'),
          _MilestoneTrackerSection(
            contract: c,
            isOwner: _isOwner,
            isBuilder: _isBuilder,
            currentUserName: widget.signerName,
          ),

          const SizedBox(height: 16),

          // Signatures
          _SectionTitle('Signatures'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SignatureRow(
                    label: 'Owner',
                    name: c.ownerSignatureName,
                    signedAt: c.ownerSignedAt,
                    fmtFull: fmtFull,
                  ),
                  const Divider(height: 24),
                  if (c.builderSignatureName != null)
                    _SignatureRow(
                      label: 'Builder',
                      name: c.builderSignatureName!,
                      signedAt: c.builderSignedAt,
                      fmtFull: fmtFull,
                    )
                  else
                    Text(
                      'Builder signature pending',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.outline,
                          ),
                    ),
                ],
              ),
            ),
          ),

          // Signed PDF download link
          if (c.signedPdfUrl != null) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Download Signed Contract (PDF)'),
                onPressed: () async {
                  final uri = Uri.tryParse(c.signedPdfUrl!);
                  if (uri != null && await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ),
          ],

          // Builder sign / decline actions
          if (_isBuilder && isPending) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.error,
                      side: BorderSide(color: cs.error),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final signed = await Navigator.of(
                              context,
                            ).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => ContractSignPage(
                                  contract: widget.contract,
                                  signerName: widget.signerName,
                                ),
                              ),
                            );
                            if (signed == true && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          },
                    icon: const Icon(Icons.draw_outlined, size: 16),
                    label: const Text('Sign Contract'),
                  ),
                ),
              ],
            ),
          ],

          if (_error != null && !_isBuilder) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error, fontSize: 12)),
          ],

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.outline,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: bold ? FontWeight.w600 : null,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SignatureRow extends StatelessWidget {
  const _SignatureRow({
    required this.label,
    required this.name,
    required this.signedAt,
    required this.fmtFull,
  });
  final String label;
  final String name;
  final DateTime? signedAt;
  final DateFormat fmtFull;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: cs.outline,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
        ),
        if (signedAt != null)
          Text(
            'Signed: ${fmtFull.format(signedAt!)}',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.outline,
                ),
          ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});
  final ContractStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (color, textColor, icon) = switch (status) {
      ContractStatus.pendingBuilder => (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          Icons.pending_outlined,
        ),
      ContractStatus.active => (
          Colors.green.withValues(alpha: 0.15),
          Colors.green[800]!,
          Icons.check_circle_outline,
        ),
      ContractStatus.declined => (
          cs.errorContainer,
          cs.onErrorContainer,
          Icons.cancel_outlined,
        ),
      ContractStatus.cancelled => (
          cs.surfaceContainerHighest,
          cs.onSurfaceVariant,
          Icons.block_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 10),
          Text(
            status.label,
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Milestone tracker section ────────────────────────────────────────────────

class _MilestoneTrackerSection extends StatelessWidget {
  const _MilestoneTrackerSection({
    required this.contract,
    required this.isOwner,
    required this.isBuilder,
    required this.currentUserName,
  });

  final BuilderContract contract;
  final bool isOwner;
  final bool isBuilder;
  final String currentUserName;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final moneyFmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');
    final milestones = contract.milestones;

    if (milestones.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No payment milestones defined.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.outline,
                ),
          ),
        ),
      );
    }

    final totalPaid = milestones
        .where((m) => m.isPaid)
        .fold<double>(0.0, (sum, m) => sum + m.amountGhs);
    final totalAmount =
        milestones.fold<double>(0.0, (sum, m) => sum + m.amountGhs);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'GHS ${moneyFmt.format(totalPaid)} released of '
                    '${moneyFmt.format(totalAmount)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                ),
                Text(
                  '${milestones.where((m) => m.isPaid).length}/${milestones.length}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 0),
          for (final m in milestones)
            Builder(
              builder: (ctx) {
                final overdue = m.dueDate != null &&
                    !m.isPaid &&
                    m.dueDate!.isBefore(DateTime.now());
                final statusColor = switch (m.approvalStatus) {
                  MilestoneApprovalStatus.released => Colors.green.shade700,
                  MilestoneApprovalStatus.pendingRelease =>
                    Colors.orange.shade700,
                  _ => cs.outline,
                };
                final statusIcon = switch (m.approvalStatus) {
                  MilestoneApprovalStatus.released =>
                    Icons.check_circle_outline,
                  MilestoneApprovalStatus.pendingRelease =>
                    Icons.hourglass_top_outlined,
                  _ => overdue
                      ? Icons.warning_amber_outlined
                      : Icons.radio_button_unchecked,
                };

                Widget? trailingWidget;
                if (m.approvalStatus == MilestoneApprovalStatus.pending &&
                    isBuilder &&
                    contract.status == ContractStatus.active) {
                  trailingWidget = TextButton(
                    onPressed: () => sl<ContractService>()
                        .requestMilestoneRelease(contract.id, m.id),
                    child: const Text('Request\nRelease', textAlign: TextAlign.center),
                  );
                } else if (m.approvalStatus ==
                        MilestoneApprovalStatus.pendingRelease &&
                    isOwner) {
                  trailingWidget = FilledButton.tonal(
                    onPressed: () => MilestoneReleaseSheet.show(
                      context,
                      contract: contract,
                      milestone: m,
                      releasedByName: currentUserName,
                    ),
                    child: const Text('Release'),
                  );
                }

                return ListTile(
                  leading: Icon(statusIcon, color: statusColor, size: 22),
                  title: Text(
                    m.description,
                    style: TextStyle(
                      decoration:
                          m.isPaid ? TextDecoration.lineThrough : null,
                      color: m.isPaid ? cs.outline : null,
                    ),
                  ),
                  subtitle: Text(
                    [
                      'GHS ${moneyFmt.format(m.amountGhs)}',
                      if (m.dueDate != null)
                        'due ${dateFmt.format(m.dueDate!)}',
                      if (m.isPaid && m.paidAt != null)
                        'released ${dateFmt.format(m.paidAt!)}',
                      m.approvalStatus.label,
                    ].join(' · '),
                    style: TextStyle(
                      color: overdue ? cs.error : cs.outline,
                      fontSize: 12,
                    ),
                  ),
                  trailing: trailingWidget,
                );
              },
            ),
        ],
      ),
    );
  }
}
