import '../../core/config/service_locator.dart';
// lib/features/project/create_project_page.dart
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/models/project_template.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/project_service.dart';
import '../../core/services/regional_index_provider.dart';

class CreateProjectPage extends StatefulWidget {
  const CreateProjectPage({
    super.key,
    this.initialTitle,
    this.initialBudget,
    this.initialRegion,
    this.initialBoqItems,
    this.initialFloorAreaSqm,
    this.template,
  });

  final String? initialTitle;
  final double? initialBudget;
  final String? initialRegion;

  /// BOQ items (as maps from BoqItem.toMap()) to freeze with this project.
  final List<Map<String, dynamic>>? initialBoqItems;
  final double? initialFloorAreaSqm;

  /// Pre-fill form from a saved template (title, budget, region, description)
  /// and seed phases after creation.
  final ProjectTemplate? template;

  @override
  State<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends State<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _budgetCtrl = TextEditingController();
  final _permitNumberCtrl = TextEditingController();
  final _contingencyCtrl = TextEditingController();

  String? _region;
  DateTime? _permitApprovalDate;
  bool _saving = false;
  String? _error;
  bool _draftSaved = false;

  String? _draftKey;

  @override
  void initState() {
    super.initState();
    // Template pre-fill takes precedence over individual initial params.
    final tmpl = widget.template;
    if (tmpl != null) {
      _titleCtrl.text = tmpl.name;
      _descCtrl.text = tmpl.description;
      _budgetCtrl.text = tmpl.budget > 0 ? tmpl.budget.toStringAsFixed(0) : '';
      _region = tmpl.region.isEmpty ? null : tmpl.region;
    } else {
      if (widget.initialTitle != null) _titleCtrl.text = widget.initialTitle!;
      if (widget.initialBudget != null) {
        _budgetCtrl.text = widget.initialBudget!.toStringAsFixed(0);
      }
      if (widget.initialRegion != null) _region = widget.initialRegion;
    }
    // Only enable draft save when no template/prefill is provided.
    if (tmpl == null &&
        widget.initialTitle == null &&
        widget.initialBudget == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initDraft());
    }
  }

  Future<void> _initDraft() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid;
    if (uid == null) return;
    _draftKey = 'draft_project_$uid';
    _titleCtrl.addListener(_saveDraft);
    _descCtrl.addListener(_saveDraft);
    _budgetCtrl.addListener(_saveDraft);
    _locationCtrl.addListener(_saveDraft);
    _permitNumberCtrl.addListener(_saveDraft);
    _contingencyCtrl.addListener(_saveDraft);
    await _loadDraft();
  }

  Future<void> _loadDraft() async {
    if (_draftKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey!);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        if (_titleCtrl.text.isEmpty) _titleCtrl.text = map['title'] as String? ?? '';
        if (_descCtrl.text.isEmpty) _descCtrl.text = map['desc'] as String? ?? '';
        if (_budgetCtrl.text.isEmpty) _budgetCtrl.text = map['budget'] as String? ?? '';
        if (_locationCtrl.text.isEmpty) _locationCtrl.text = map['location'] as String? ?? '';
        if (_permitNumberCtrl.text.isEmpty) {
          _permitNumberCtrl.text = map['permitNumber'] as String? ?? '';
        }
        if (_contingencyCtrl.text.isEmpty) {
          _contingencyCtrl.text = map['contingency'] as String? ?? '';
        }
        _region ??= map['region'] as String?;
      });
    } catch (_) {
      // Ignore corrupt draft.
    }
  }

  Future<void> _saveDraft() async {
    if (_draftKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    final map = {
      'title': _titleCtrl.text,
      'desc': _descCtrl.text,
      'budget': _budgetCtrl.text,
      'location': _locationCtrl.text,
      'region': _region,
      'permitNumber': _permitNumberCtrl.text,
      'contingency': _contingencyCtrl.text,
    };
    await prefs.setString(_draftKey!, jsonEncode(map));
    if (mounted && !_draftSaved) setState(() => _draftSaved = true);
  }

  Future<void> _clearDraft() async {
    if (_draftKey == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey!);
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_saveDraft);
    _descCtrl.removeListener(_saveDraft);
    _budgetCtrl.removeListener(_saveDraft);
    _locationCtrl.removeListener(_saveDraft);
    _permitNumberCtrl.removeListener(_saveDraft);
    _contingencyCtrl.removeListener(_saveDraft);
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
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthService>();
      final projectService = sl<ProjectService>();
      final uid = auth.currentUser!.uid;
      final now = DateTime.now();

      final project = Project(
        id: '',
        ownerUid: uid,
        ownerName: auth.currentUser?.displayName,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        region: _region ?? '',
        budget: double.tryParse(_budgetCtrl.text) ?? 0,
        permitNumber: _permitNumberCtrl.text.trim().isEmpty
            ? null
            : _permitNumberCtrl.text.trim(),
        permitApprovalDate: _permitApprovalDate,
        contingencyGhs: double.tryParse(_contingencyCtrl.text.trim()) ?? 0,
        createdAt: now,
        updatedAt: now,
      );

      final projectId = await projectService.createProject(project);

      if (widget.initialBoqItems != null &&
          widget.initialBoqItems!.isNotEmpty) {
        await projectService.saveBoq(
          projectId,
          widget.initialBoqItems!,
          widget.initialFloorAreaSqm ?? 0,
        );
      }

      // Seed phases from template.
      if (widget.template != null) {
        for (int i = 0; i < widget.template!.phases.length; i++) {
          final tp = widget.template!.phases[i];
          await projectService.addPhase(
            projectId,
            Phase(
              id: '',
              name: tp.name,
              order: i,
              estimatedCostGhs: tp.estimatedCostGhs,
              actualCostGhs: 0,
              status: PhaseStatus.pending,
              createdAt: DateTime.now(),
            ),
          );
        }
      }

      await _clearDraft();
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final regions = context.read<RegionalIndexProvider>().regionCodes;

    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Project title *',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: (s) =>
                  (s == null || s.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),

            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 14),

            // Location
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                hintText: 'e.g. Tema, Community 9',
                border: OutlineInputBorder(),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 14),

            // Region
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Region (optional)',
                border: OutlineInputBorder(),
              ),
              initialValue: _region,
              items: [
                const DropdownMenuItem(value: null, child: Text('— Select —')),
                for (final r in regions)
                  DropdownMenuItem(value: r, child: Text(r)),
              ],
              onChanged: (v) => setState(() => _region = v),
            ),
            const SizedBox(height: 14),

            // Budget
            TextFormField(
              controller: _budgetCtrl,
              decoration: const InputDecoration(
                labelText: 'Budget (GHS, optional)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v);
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 14),

            // Permit number
            TextFormField(
              controller: _permitNumberCtrl,
              decoration: const InputDecoration(
                labelText: 'Building Permit No. (optional)',
                hintText: 'e.g. DA/BP/2024/001',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 14),

            // Permit approval date
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
            const SizedBox(height: 14),

            // Contingency
            TextFormField(
              controller: _contingencyCtrl,
              decoration: const InputDecoration(
                labelText: 'Contingency Reserve (GHS, optional)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 8),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  _error!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),

            const SizedBox(height: 8),

            if (_draftSaved)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Draft saved',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  textAlign: TextAlign.end,
                ),
              ),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Saving…' : 'Create project'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
