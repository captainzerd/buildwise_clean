// lib/features/estimate/widgets/add_expense_dialog.dart
import 'package:flutter/material.dart';

class AddExpenseDialog extends StatefulWidget {
  final List<String> phases;
  final void Function({
    required String phase,
    required double amountGhs,
    String? vendor,
    String? note,
  }) onAdd;

  const AddExpenseDialog({
    super.key,
    required this.phases,
    required this.onAdd,
  });

  @override
  State<AddExpenseDialog> createState() => _AddExpenseDialogState();
}

class _AddExpenseDialogState extends State<AddExpenseDialog> {
  String? _phase;
  final _amount = TextEditingController();
  final _vendor = TextEditingController();
  final _note = TextEditingController();

  @override
  void initState() {
    super.initState();
    _phase = widget.phases.isNotEmpty ? widget.phases.first : null;
  }

  @override
  void dispose() {
    _amount.dispose();
    _vendor.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add expense'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _phase, // ← use initialValue (not value)
              items: widget.phases
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _phase = v),
              decoration: const InputDecoration(
                labelText: 'Phase',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount (GHS)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _vendor,
              decoration: const InputDecoration(
                labelText: 'Vendor (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final amt = double.tryParse(_amount.text.trim()) ?? 0;
            if ((_phase ?? '').isEmpty || amt <= 0) return;
            widget.onAdd(
              phase: _phase!,
              amountGhs: amt,
              vendor: _vendor.text.trim().isEmpty ? null : _vendor.text.trim(),
              note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            );
            Navigator.pop(context);
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}
