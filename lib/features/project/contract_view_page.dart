import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/builder_contract.dart';
import '../../core/services/contract_service.dart';

class ContractViewPage extends StatefulWidget {
  const ContractViewPage({
    super.key,
    required this.contract,
    required this.currentUserUid,
    required this.contractService,
  });

  final BuilderContract contract;
  final String currentUserUid;
  final ContractService contractService;

  @override
  State<ContractViewPage> createState() => _ContractViewPageState();
}

class _ContractViewPageState extends State<ContractViewPage> {
  final _sigCtrl = TextEditingController();
  bool _busy = false;
  String? _error;

  bool get _isOwner => widget.currentUserUid == widget.contract.ownerUid;
  bool get _isBuilder => widget.currentUserUid == widget.contract.builderUid;

  @override
  void dispose() {
    _sigCtrl.dispose();
    super.dispose();
  }

  Future<void> _accept() async {
    if (_sigCtrl.text.trim().length < 3) {
      setState(() => _error = 'Please type your full name to sign.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.contractService.builderAccept(
        contract: widget.contract,
        signatureName: _sigCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract signed. You are now assigned to the project.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
      await widget.contractService.builderDecline(widget.contract.id);
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
      await widget.contractService.ownerCancel(widget.contract.id);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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

          // Builder sign / decline actions
          if (_isBuilder && isPending) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: cs.outlineVariant),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.draw_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Text(
                        'Your Signature',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By typing your full name and tapping Accept, you agree to '
                    'the terms above under the Ghana Electronic Transactions '
                    'Act, 2008.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _sigCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Type your full name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _error!,
                      style: TextStyle(color: cs.error, fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 16),
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
                        child: FilledButton(
                          onPressed: _busy ? null : _accept,
                          child: _busy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Accept & Sign'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
