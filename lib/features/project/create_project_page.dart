// lib/features/project/create_project_page.dart
import 'dart:convert';
import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/phase.dart';
import '../../core/models/project.dart';
import '../../core/models/project_document.dart';
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
  String? _projectType;
  String? _buildingType;
  double? _latitude;
  double? _longitude;
  bool _gettingLocation = false;
  String? _architecturePlanUrl;
  String? _archPlanFileName;
  String? _archPlanContentType;
  bool _uploadingPlan = false;
  DateTime? _permitApprovalDate;
  bool _saving = false;
  String? _error;
  bool _draftSaved = false;

  String? _draftKey;

  static const _projectTypes = [
    ('residential', 'Residential'),
    ('commercial', 'Commercial'),
    ('industrial', 'Industrial'),
    ('infrastructure', 'Infrastructure'),
  ];

  static const _buildingTypes = [
    ('bungalow', 'Bungalow'),
    ('duplex', 'Duplex'),
    ('terraced', 'Terraced House'),
    ('apartment_block', 'Apartment Block'),
    ('office', 'Office Building'),
    ('warehouse', 'Warehouse'),
    ('mixed_use', 'Mixed Use'),
    ('other', 'Other'),
  ];

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

  String? _inferContentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      _ => null,
    };
  }

  Future<void> _uploadArchitecturePlan() async {
    final uid = context.read<AuthService>().currentUser?.uid ?? 'anon';
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'dwg'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;

    setState(() {
      _archPlanFileName = file.name;
      _archPlanContentType = _inferContentType(file.name);
    });

    setState(() => _uploadingPlan = true);
    try {
      final ref = FirebaseStorage.instance
          .ref('project_docs/$uid/arch_plans/${file.name}');
      await ref.putFile(File(file.path!));
      final url = await ref.getDownloadURL();
      setState(() => _architecturePlanUrl = url);
    } catch (_) {
      // Ignore upload error — user can retry.
    } finally {
      if (mounted) setState(() => _uploadingPlan = false);
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

      // Enforce server-side quota before creating.
      try {
        await FirebaseFunctions.instance
            .httpsCallable('enforceProjectQuota')
            .call();
      } on FirebaseFunctionsException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Project limit reached')),
        );
        return;
      }

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
        latitude: _latitude,
        longitude: _longitude,
        projectType: _projectType,
        buildingType: _buildingType,
        architecturePlanUrl: _architecturePlanUrl,
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

      // Save architecture plan as a ProjectDocument.
      if (_architecturePlanUrl != null && _archPlanFileName != null) {
        try {
          final archDoc = ProjectDocument(
            id: '',
            uploaderUid: uid,
            name: _archPlanFileName!,
            url: _architecturePlanUrl!,
            category: DocumentCategory.architecturalDrawing,
            storagePath: 'project_docs/$uid/arch_plans/$_archPlanFileName',
            contentType: _archPlanContentType,
            visibility: DocumentVisibility.all,
            createdAt: DateTime.now(),
          );
          await projectService.addDocument(projectId, archDoc);
        } catch (e) {
          debugPrint('addDocument (arch plan) failed: $e');
        }
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

      // If no template was provided, prompt to apply the default Ghana build template.
      if (widget.template == null) {
        await _promptDefaultTemplate(context, projectId, projectService);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static const _defaultStages = [
    'Land Acquisition',
    'Design & Planning',
    'Permit Approval',
    'Substructure / Foundation',
    'Superstructure',
    'Roofing',
    'Mechanical, Electrical & Plumbing',
    'Finishing',
    'External Works & Landscaping',
    'Final Inspection & Handover',
  ];

  Future<void> _promptDefaultTemplate(
    BuildContext ctx,
    String projectId,
    ProjectService ps,
  ) async {
    final apply = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Apply Standard Stages?'),
        content: const Text(
          'Would you like to start with the standard Ghana construction stages?\n\n'
          'Land Acquisition → Design → Permit → Foundation → Superstructure → '
          'Roofing → MEP → Finishing → External Works → Handover',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Start blank'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Apply template'),
          ),
        ],
      ),
    );
    if (apply != true || !ctx.mounted) return;
    for (int i = 0; i < _defaultStages.length; i++) {
      await ps.addPhase(
        projectId,
        Phase(
          id: '',
          name: _defaultStages[i],
          order: i,
          status: PhaseStatus.pending,
          createdAt: DateTime.now(),
        ),
      );
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

            // Project type
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Project type (optional)',
                border: OutlineInputBorder(),
              ),
              initialValue: _projectType,
              items: [
                const DropdownMenuItem(value: null, child: Text('— Select —')),
                for (final t in _projectTypes)
                  DropdownMenuItem(value: t.$1, child: Text(t.$2)),
              ],
              onChanged: (v) => setState(() => _projectType = v),
            ),
            const SizedBox(height: 14),

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
            const SizedBox(height: 8),

            // GPS location capture
            Row(
              children: [
                if (_latitude != null)
                  Expanded(
                    child: Text(
                      'GPS: ${_latitude!.toStringAsFixed(5)}, '
                      '${_longitude!.toStringAsFixed(5)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  )
                else
                  const Expanded(
                    child: Text('No GPS captured', style: TextStyle(fontSize: 12)),
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
                  label: Text(_latitude != null ? 'Retake GPS' : 'Use GPS'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Architecture plan upload
            _PlanUploadTile(
              url: _architecturePlanUrl,
              uploading: _uploadingPlan,
              onUpload: _uploadArchitecturePlan,
              onClear: () => setState(() => _architecturePlanUrl = null),
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

class _PlanUploadTile extends StatelessWidget {
  const _PlanUploadTile({
    required this.url,
    required this.uploading,
    required this.onUpload,
    required this.onClear,
  });

  final String? url;
  final bool uploading;
  final VoidCallback onUpload;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        url != null ? Icons.picture_as_pdf : Icons.upload_file_outlined,
        color: url != null
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      title: Text(
        url != null ? 'Architecture plan uploaded' : 'Architecture plan (optional)',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: url != null
          ? Text(
              'Tap × to remove',
              style: Theme.of(context).textTheme.bodySmall,
            )
          : null,
      trailing: uploading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : url != null
              ? IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClear,
                )
              : OutlinedButton(
                  onPressed: onUpload,
                  child: const Text('Upload'),
                ),
    );
  }
}
