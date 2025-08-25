import 'package:flutter/material.dart';

/// A small, reusable action row shown when an estimate exists.
/// Keeps UI logic out of the page/controller.
class EstimateActions extends StatelessWidget {
  final bool hasResult;

  /// Save the currently generated estimate.
  final Future<void> Function()? onSave;

  /// Export the current estimate to PDF.
  final Future<void> Function()? onExportPdf;

  /// Open an add‑expense dialog or sheet.
  /// We hand the BuildContext so callers can present UI as needed.
  final Future<void> Function(BuildContext context)? onAddExpense;

  const EstimateActions({
    super.key,
    required this.hasResult,
    this.onSave,
    this.onExportPdf,
    this.onAddExpense,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = !hasResult;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          onPressed: disabled ? null : () => onSave?.call(),
          icon: const Icon(Icons.save),
          label: const Text('Save'),
        ),
        OutlinedButton.icon(
          onPressed: disabled ? null : () => onExportPdf?.call(),
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Export PDF'),
        ),
        OutlinedButton.icon(
          onPressed: disabled ? null : () => onAddExpense?.call(context),
          icon: const Icon(Icons.attach_money),
          label: const Text('Add Expense'),
        ),
      ],
    );
  }
}
