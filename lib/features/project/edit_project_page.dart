// lib/features/project/edit_project_page.dart
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
  String? _buildingType;
  int _updateFrequencyDays = 7;
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  DateTime? _permitApprovalDate;
  bool _saving = false;
  String? _error;

  static const _buildingTypes = [
    ('residentialStandard', 'Residential — Bungalow / Duplex'),
    ('residentialMediumRise', 'Residential — Medium-rise (3–6 floors)'),
    ('residentialHighRise', 'Residential — High-rise (7+ floors)'),
  ];

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
    _buildingType = p.buildingType;
    _updateFrequencyDays = p.updateFrequencyDays;
    _latitude = p.latitude;
    _longitude = p.longitude;
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

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude = pos.latitude;
        _longitude = pos.longitude;
      });
    } catch (_) {
      // Silently ignore location errors.
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
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
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
        if (_locationCtrl.text.trim().isNotEmpty)
          'location': _locationCtrl.text.trim(),
        if (_latitude != null) 'latitude': _latitude,
        if (_longitude != null) 'longitude': _longitude,
        'projectType': 'residential',
        if (_buildingType != null) 'buildingType': _buildingType,
        'budget': budget,
        'budgetAlertThreshold': _alertThreshold,
        if (_permitNumberCtrl.text.trim().isNotEmpty)
          'permitNumber': _permitNumberCtrl.text.trim(),
        if (_permitApprovalDate != null)
          'permitApprovalDate': _permitApprovalDate!.toIso8601String(),
        'contingencyGhs': double.tryParse(_contingencyCtrl.text.trim()) ?? 0,
        'updateFrequencyDays': _updateFrequencyDays,
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
            // Building type
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Building type (optional)',
                border: OutlineInputBorder(),
              ),
              initialValue: _buildingType,
              items: [
                const DropdownMenuItem(value: null, child: Text('— Select —')),
                for (final t in _buildingTypes)
                  DropdownMenuItem(value: t.$1, child: Text(t.$2)),
              ],
              onChanged: (v) => setState(() => _buildingType = v),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Location (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            // GPS
            Row(
              children: [
                Expanded(
                  child: Text(
                    _latitude != null
                        ? 'GPS: ${_latitude!.toStringAsFixed(5)}, '
                            '${_longitude!.toStringAsFixed(5)}'
                        : 'No GPS recorded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _latitude != null
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _gettingLocation ? null : _getCurrentLocation,
                  icon: _gettingLocation
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.my_location, size: 18),
                  label: Text(_latitude != null ? 'Retake' : 'GPS'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _budgetCtrl,
              decoration: const InputDecoration(
                labelText: 'Budget (GHS)',
                prefixText: 'GH₵ ',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
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
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                final n = double.tryParse(v.trim());
                if (n == null || n < 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Required update frequency
            DropdownButtonFormField<int>(
              initialValue: _updateFrequencyDays,
              decoration: const InputDecoration(
                labelText: 'Required update frequency',
                helperText: 'How often should the builder post a progress update?',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Not required')),
                DropdownMenuItem(value: 7, child: Text('Weekly')),
                DropdownMenuItem(value: 14, child: Text('Fortnightly')),
              ],
              onChanged: (v) => setState(() => _updateFrequencyDays = v ?? 7),
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
