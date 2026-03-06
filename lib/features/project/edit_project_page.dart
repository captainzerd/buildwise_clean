// lib/features/project/edit_project_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/project.dart';
import '../../core/services/project_service.dart';

class EditProjectPage extends StatefulWidget {
  const EditProjectPage({
    super.key,
    required this.project,
  });

  final Project project;

  @override
  State<EditProjectPage> createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _locationCtrl;
  late final TextEditingController _budgetCtrl;
  late final TextEditingController _permitNumberCtrl;
  late final TextEditingController _contingencyCtrl;
  late double _alertThreshold;
  DateTime? _permitApprovalDate;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    _titleCtrl = TextEditingController(text: p.title);
    _descCtrl = TextEditingController(text: p.description ?? '');
    _locationCtrl = TextEditingController(text: p.location ?? '');
    _budgetCtrl = TextEditingController(
      text: p.budget > 0 ? p.budget.toStringAsFixed(0) : '',
    );
    _permitNumberCtrl = TextEditingController(text: p.permitNumber ?? '');
    _contingencyCtrl = TextEditingController(
      text: p.contingencyGhs > 0 ? p.contingencyGhs.toStringAsFixed(0) : '',
    );
    _alertThreshold = p.budgetAlertThreshold.clamp(0.5, 0.95);
    _permitApprovalDate = p.permitApprovalDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _locationCtrl.dispose();
    _budgetCtrl.dispose();
    _permitNumberCtrl.dispose();
    _contingencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPermitDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _permitApprovalDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _permitApprovalDate = picked);
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final budget = double.tryParse(_budgetCtrl.text) ?? widget.project.budget;
      await sl<ProjectService>().updateProject(widget.project.id, {
        'title': _titleCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
        'budget': budget,
        'budgetAlertThreshold': _alertThreshold,
        if (_permitNumberCtrl.text.trim().isNotEmpty)
          'permitNumber': _permitNumberCtrl.text.trim(),
        if (_permitApprovalDate != null)
          'permitApprovalDate': _permitApprovalDate!.toIso8601String(),
        'contingencyGhs':
            double.tryParse(_contingencyCtrl.text.trim()) ?? 0,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final thresholdPct = (_alertThreshold * 100).round();

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Project title *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetCtrl,
              decoration: const InputDecoration(
                labelText: 'Budget (GHS)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _permitNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Building Permit No. (optional)',
                hintText: 'e.g. DA/BP/2024/001',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickPermitDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Permit Approval Date (optional)',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                ),
                child: Text(
                  _permitApprovalDate != null
                      ? DateFormat('d MMM yyyy').format(_permitApprovalDate!)
                      : 'Not set',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _permitApprovalDate == null
                            ? Theme.of(context).colorScheme.outline
                            : null,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _contingencyCtrl,
              decoration: const InputDecoration(
                labelText: 'Contingency Reserve (GHS, optional)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Budget alert threshold: $thresholdPct%',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              'Show a warning when spending reaches $thresholdPct% of the budget.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            Slider(
              value: _alertThreshold,
              min: 0.5,
              max: 0.95,
              divisions: 9,
              label: '$thresholdPct%',
              onChanged: (v) => setState(() => _alertThreshold = v),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving…' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
