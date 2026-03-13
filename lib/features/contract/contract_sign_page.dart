// lib/features/contract/contract_sign_page.dart
//
// Allows a builder to review a contract and sign it using a drawn signature.
// On submit, the signature PNG is embedded in a PDF and uploaded to Storage.

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../core/config/service_locator.dart';
import '../../core/errors/app_exception.dart';
import '../../core/models/builder_contract.dart';
import '../../core/services/contract_service.dart';

class ContractSignPage extends StatefulWidget {
  const ContractSignPage({
    super.key,
    required this.contract,
    required this.signerName,
  });

  final BuilderContract contract;
  final String signerName;

  @override
  State<ContractSignPage> createState() => _ContractSignPageState();
}

class _ContractSignPageState extends State<ContractSignPage> {
  late final SignatureController _sigCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sigCtrl = SignatureController(
      penStrokeWidth: 2.5,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
  }

  @override
  void dispose() {
    _sigCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sigCtrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please draw your signature first.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm signature'),
        content: const Text(
          'By tapping "Sign & Accept" you agree to the contract terms. '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign & Accept'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _saving = true);
    try {
      final pngBytes = await _sigCtrl.toPngBytes();
      if (pngBytes == null) throw Exception('Failed to export signature.');

      await sl<ContractService>().uploadSignatureAndSign(
        contract: widget.contract,
        signerName: widget.signerName,
        signaturePng: pngBytes,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contract signed successfully!')),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppException.from(e).message), duration: const Duration(seconds: 10)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final contract = widget.contract;
    final fmt = NumberFormat('#,##0.00');
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Contract')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contract summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contract.projectTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 8),
                  _Row('Builder', contract.builderName),
                  _Row(
                    'Total',
                    'GH₵ ${fmt.format(contract.totalAmountGhs)}',
                  ),
                  if (contract.startDate != null)
                    _Row(
                      'Start',
                      _dateFmt(contract.startDate!),
                    ),
                  if (contract.endDate != null)
                    _Row('End', _dateFmt(contract.endDate!)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Scope
          Text(
            'Scope of Work',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(contract.scope),
          const SizedBox(height: 12),

          // Milestones
          if (contract.milestones.isNotEmpty) ...[
            Text(
              'Payment Milestones',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ...contract.milestones.map(
              (m) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(m.description)),
                    Text(
                      'GH₵ ${fmt.format(m.amountGhs)}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          const Divider(),
          const SizedBox(height: 12),

          // Signature pad
          Text(
            'Draw your signature below',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              border: Border.all(color: cs.outline),
              borderRadius: BorderRadius.circular(8),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Signature(
                controller: _sigCtrl,
                backgroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              icon: const Icon(Icons.clear, size: 16),
              label: const Text('Clear'),
              onPressed: () => _sigCtrl.clear(),
            ),
          ),
          const SizedBox(height: 8),

          // Sign button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.draw_outlined, size: 18),
              label: const Text('Sign & Accept Contract'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _dateFmt(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
