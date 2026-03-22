import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/service_locator.dart';
import '../../core/models/work_experience.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/work_experience_service.dart';

class WorkExperiencePage extends StatelessWidget {
  const WorkExperiencePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthService>().currentUser?.uid ?? '';
    return Scaffold(
      appBar: AppBar(title: const Text('Work History')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context, uid),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<WorkExperience>>(
        stream: sl<WorkExperienceService>().stream(uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.work_outline, size: 56, color: Colors.grey),
                  SizedBox(height: 8),
                  Text('No work history yet'),
                  SizedBox(height: 4),
                  Text(
                    'Tap + to add your first entry',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            itemBuilder: (_, i) => _WorkExperienceTile(
              experience: items[i],
              uid: uid,
            ),
          );
        },
      ),
    );
  }

  void _showAddSheet(BuildContext context, String uid) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _AddWorkExperienceSheet(uid: uid),
    );
  }
}

class _WorkExperienceTile extends StatelessWidget {
  const _WorkExperienceTile({
    required this.experience,
    required this.uid,
  });

  final WorkExperience experience;
  final String uid;

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text(
          'Remove "${experience.projectOrEmployer}" from your work history?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await sl<WorkExperienceService>().delete(uid, experience.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM yyyy');
    final period = experience.isCurrent
        ? '${fmt.format(experience.startDate)} – Present'
        : '${fmt.format(experience.startDate)} – ${fmt.format(experience.endDate!)}';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        title: Text(
          experience.projectOrEmployer,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(experience.roleTitle),
            Text(
              period,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (experience.region != null)
              Text(
                experience.region!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (experience.contractValueGhs != null)
              Text(
                'Value: GHS ${experience.contractValueGhs!.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (experience.description != null) ...[
              const SizedBox(height: 4),
              Text(experience.description!),
            ],
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          color: Theme.of(context).colorScheme.error,
          onPressed: () => _confirmDelete(context),
        ),
      ),
    );
  }
}

class _AddWorkExperienceSheet extends StatefulWidget {
  const _AddWorkExperienceSheet({required this.uid});
  final String uid;

  @override
  State<_AddWorkExperienceSheet> createState() =>
      _AddWorkExperienceSheetState();
}

class _AddWorkExperienceSheetState extends State<_AddWorkExperienceSheet> {
  final _formKey = GlobalKey<FormState>();
  final _employerCtrl = TextEditingController();
  final _roleTitleCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isCurrent = true;
  bool _busy = false;

  @override
  void dispose() {
    _employerCtrl.dispose();
    _roleTitleCtrl.dispose();
    _regionCtrl.dispose();
    _valueCtrl.dispose();
    _descCtrl.dispose();
    _refCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : (_endDate ?? DateTime.now()),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final exp = WorkExperience(
        id: const Uuid().v4(),
        projectOrEmployer: _employerCtrl.text.trim(),
        roleTitle: _roleTitleCtrl.text.trim(),
        startDate: _startDate,
        endDate: _isCurrent ? null : _endDate,
        region: _regionCtrl.text.trim().isNotEmpty
            ? _regionCtrl.text.trim()
            : null,
        contractValueGhs: double.tryParse(_valueCtrl.text),
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        clientReference: _refCtrl.text.trim().isNotEmpty
            ? _refCtrl.text.trim()
            : null,
      );
      await sl<WorkExperienceService>().add(widget.uid, exp);
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('MMM yyyy');
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Work Experience',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _employerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Project / Employer *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _roleTitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Role / Title *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _regionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Region (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _valueCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Contract Value GHS (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text('Start: ${fmt.format(_startDate)}'),
                      onPressed: () => _pickDate(isStart: true),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                title: const Text('Currently working here'),
                value: _isCurrent,
                onChanged: (v) => setState(() {
                  _isCurrent = v;
                  if (v) _endDate = null;
                }),
                contentPadding: EdgeInsets.zero,
              ),
              if (!_isCurrent)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text(
                          _endDate != null
                              ? 'End: ${fmt.format(_endDate!)}'
                              : 'Pick end date',
                        ),
                        onPressed: () => _pickDate(isStart: false),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _refCtrl,
                decoration: const InputDecoration(
                  labelText: 'Client Reference (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
