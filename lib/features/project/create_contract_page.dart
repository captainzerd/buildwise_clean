import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/builder_contract.dart';
import '../../core/models/builder_profile.dart';
import '../../core/services/contract_service.dart';

class CreateContractPage extends StatefulWidget {
  const CreateContractPage({
    super.key,
    required this.projectId,
    required this.projectTitle,
    required this.builder,
    required this.ownerUid,
  });

  final String projectId;
  final String projectTitle;
  final BuilderProfile builder;
  final String ownerUid;

  @override
  State<CreateContractPage> createState() => _CreateContractPageState();
}

class _CreateContractPageState extends State<CreateContractPage> {
  final _formKey = GlobalKey<FormState>();
  final _scopeCtrl = TextEditingController();
  final _totalCtrl = TextEditingController();
  final _sigCtrl = TextEditingController();

  ContractTemplateType _template = ContractTemplateType.custom;
  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _dlpEndDate;
  bool _saving = false;
  String? _error;

  final List<_MilestoneRow> _milestones = [];

  @override
  void dispose() {
    _scopeCtrl.dispose();
    _totalCtrl.dispose();
    _sigCtrl.dispose();
    for (final m in _milestones) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<void> _pickDlpDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (_endDate ?? DateTime.now()).add(const Duration(days: 365)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) setState(() => _dlpEndDate = picked);
  }

  void _addMilestone() {
    setState(() => _milestones.add(_MilestoneRow()));
  }

  void _removeMilestone(int index) {
    _milestones[index].dispose();
    setState(() => _milestones.removeAt(index));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate milestone sum equals contract total (±1 GHS)
    if (_milestones.isNotEmpty) {
      final total = double.tryParse(_totalCtrl.text.trim()) ?? 0;
      final milestoneSum = _milestones.fold(
        0.0,
        (sum, m) => sum + (double.tryParse(m.amountCtrl.text.trim()) ?? 0),
      );
      if ((milestoneSum - total).abs() > 1.0) {
        setState(() {
          _error =
              'Milestone amounts (₵${milestoneSum.toStringAsFixed(2)}) must equal '
              'the contract total (₵${total.toStringAsFixed(2)}).';
        });
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      const uuid = Uuid();
      final milestones = _milestones
          .map(
            (m) => PaymentMilestone(
              id: uuid.v4(),
              description: m.descCtrl.text.trim(),
              amountGhs: double.tryParse(m.amountCtrl.text.trim()) ?? 0,
            ),
          )
          .where((m) => m.description.isNotEmpty)
          .toList();

      final contract = BuilderContract(
        id: '',
        projectId: widget.projectId,
        projectTitle: widget.projectTitle,
        ownerUid: widget.ownerUid,
        builderUid: widget.builder.uid,
        builderName: widget.builder.displayName,
        scope: _scopeCtrl.text.trim(),
        templateType: _template,
        startDate: _startDate,
        endDate: _endDate,
        dlpEndDate: _dlpEndDate,
        totalAmountGhs: double.tryParse(_totalCtrl.text.trim()) ?? 0,
        milestones: milestones,
        status: ContractStatus.pendingBuilder,
        ownerSignatureName: _sigCtrl.text.trim(),
        ownerSignedAt: now,
        createdAt: now,
        updatedAt: now,
      );

      await sl<ContractService>().createContract(contract);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contract created. Awaiting builder signature.'),
        ),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fmt = DateFormat('d MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Create Contract')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Builder info
            Card(
              color: cs.primaryContainer,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: cs.primary,
                  child: Text(
                    _initials(widget.builder.displayName),
                    style: TextStyle(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Text(
                  widget.builder.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(widget.builder.role.label),
              ),
            ),
            const SizedBox(height: 16),

            // Project
            _SectionLabel('Project: ${widget.projectTitle}'),
            const SizedBox(height: 16),

            // Template selector
            Text(
              'Contract Template',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            RadioGroup<ContractTemplateType>(
              groupValue: _template,
              onChanged: (v) => setState(() {
                _template = v ?? ContractTemplateType.custom;
                if (_template != ContractTemplateType.custom) {
                  _scopeCtrl.text = _template.templateClauses.join('\n\n');
                }
              }),
              child: Column(
                children: ContractTemplateType.values
                    .map(
                      (t) => RadioListTile<ContractTemplateType>(
                        title: Text(t.displayName),
                        subtitle: t == ContractTemplateType.custom
                            ? const Text('Write your own clauses')
                            : Text(
                                '${t.templateClauses.length} standard clauses pre-populated',
                              ),
                        value: t,
                        contentPadding: EdgeInsets.zero,
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Scope
            TextFormField(
              controller: _scopeCtrl,
              decoration: const InputDecoration(
                labelText: 'Scope of work *',
                hintText: 'Describe the work to be done in detail…',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => (v == null || v.trim().length < 20)
                  ? 'Please describe the scope (min 20 characters)'
                  : null,
            ),
            const SizedBox(height: 14),

            // Dates
            Row(
              children: [
                Expanded(
                  child: _DateField(
                    label: 'Start date',
                    value: _startDate != null ? fmt.format(_startDate!) : null,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    label: 'End date',
                    value: _endDate != null ? fmt.format(_endDate!) : null,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _DateField(
              label: 'DLP end date (optional)',
              value: _dlpEndDate != null ? fmt.format(_dlpEndDate!) : null,
              onTap: _pickDlpDate,
            ),
            const SizedBox(height: 14),

            // Total amount
            TextFormField(
              controller: _totalCtrl,
              decoration: const InputDecoration(
                labelText: 'Total contract value (GHS) *',
                prefixText: '₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.trim());
                if (n == null || n <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 20),

            // Payment milestones
            Row(
              children: [
                Text(
                  'Payment Milestones',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: _addMilestone,
                ),
              ],
            ),
            if (_milestones.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No milestones added. The total amount will be paid in full.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                      ),
                ),
              ),
            for (int i = 0; i < _milestones.length; i++)
              _MilestoneTile(
                row: _milestones[i],
                index: i,
                onRemove: () => _removeMilestone(i),
              ),
            const SizedBox(height: 24),

            // E-signature section
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
                        'Owner Signature',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By typing your full name below, you agree to the terms '
                    'above and confirm this constitutes a legally binding '
                    'signature under the Ghana Electronic Transactions Act, 2008.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.outline,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sigCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Type your full name *',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (v) =>
                        (v == null || v.trim().length < 3) ? 'Required' : null,
                  ),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(color: cs.error, fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white,),
                      )
                    : const Icon(Icons.send_outlined),
                label: Text(_saving ? 'Sending…' : 'Sign & Send to Builder'),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
      );
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(
          value ?? 'Not set',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: value == null
                    ? Theme.of(context).colorScheme.outline
                    : null,
              ),
        ),
      ),
    );
  }
}

class _MilestoneRow {
  final descCtrl = TextEditingController();
  final amountCtrl = TextEditingController();

  void dispose() {
    descCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _MilestoneTile extends StatelessWidget {
  const _MilestoneTile({
    required this.row,
    required this.index,
    required this.onRemove,
  });
  final _MilestoneRow row;
  final int index;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              controller: row.descCtrl,
              decoration: InputDecoration(
                labelText: 'Milestone ${index + 1}',
                hintText: 'e.g. Foundation complete',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextField(
              controller: row.amountCtrl,
              decoration: const InputDecoration(
                labelText: 'GHS',
                prefixText: '₵ ',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.remove_circle_outline, size: 20),
            color: Theme.of(context).colorScheme.error,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }
}
