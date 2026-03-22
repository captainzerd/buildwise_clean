// lib/features/estimate/edit_saved_estimate_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EditSavedEstimatePage extends StatefulWidget {
  const EditSavedEstimatePage({
    super.key,
    required this.projectId,
    required this.estimateId,
    required this.initial,
  });

  final String projectId;
  final String estimateId;
  final Map<String, dynamic> initial;

  @override
  State<EditSavedEstimatePage> createState() => _EditSavedEstimatePageState();
}

class _EditSavedEstimatePageState extends State<EditSavedEstimatePage> {
  late final TextEditingController _name;
  late final TextEditingController _notes;
  late final TextEditingController _budget;

  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(
      text: widget.initial['projectName'] as String? ?? '',
    );
    _notes =
        TextEditingController(text: widget.initial['notes'] as String? ?? '');
    final b = (widget.initial['budgetAmount'] as num?)?.toString() ?? '';
    _budget = TextEditingController(text: b);
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    _budget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final docRef = FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.projectId)
        .collection('estimates')
        .doc(widget.estimateId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Estimate'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => _save(docRef),
            child: _saving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: _saving,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Project / Estimate Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _budget,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Budget (GHS, optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (s) {
                  if (s == null || s.trim().isEmpty) return null;
                  final v = double.tryParse(s);
                  if (v == null || v < 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.tonalIcon(
                onPressed: _saving ? null : () => _save(docRef),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save(DocumentReference<Map<String, dynamic>> docRef) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final trimmed = _name.text.trim();
      final name = trimmed.isEmpty ? null : trimmed;
      final notes = _notes.text.trim();
      final budget = _budget.text.trim().isEmpty
          ? null
          : double.parse(_budget.text.trim());

      await docRef.update({
        if (name != null) 'projectName': name,
        'notes': notes,
        'budgetAmount': budget,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Saved.')));
        Navigator.of(context).maybePop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to save: $e'), duration: const Duration(seconds: 10)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
