// lib/features/estimate/widgets/phase_editor.dart
import 'package:flutter/material.dart';
import '../state/estimate_controller.dart';

class PhaseEditor extends StatelessWidget {
  final EstimateController ctrl;
  const PhaseEditor({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final entries = ctrl.result?.phasePlanned.entries.toList() ?? const [];
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Phase plan (editable)',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        ...entries
            .map((e) => _PhaseRow(ctrl: ctrl, phase: e.key, amount: e.value)),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _showAddDialog(context),
            icon: const Icon(Icons.add),
            label: const Text('Add phase'),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddDialog(BuildContext context) async {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Add phase'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phase name',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amtCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Planned amount (GHS)',
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
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final amt = double.tryParse(amtCtrl.text.trim()) ?? 0;
              if (name.isNotEmpty && amt > 0) {
                ctrl.addPhase(name, amt);
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _PhaseRow extends StatefulWidget {
  final EstimateController ctrl;
  final String phase;
  final double amount;
  const _PhaseRow(
      {required this.ctrl, required this.phase, required this.amount});

  @override
  State<_PhaseRow> createState() => _PhaseRowState();
}

class _PhaseRowState extends State<_PhaseRow> {
  late final TextEditingController _name =
      TextEditingController(text: widget.phase);
  late final TextEditingController _amt =
      TextEditingController(text: widget.amount.toStringAsFixed(2));

  @override
  void dispose() {
    _name.dispose();
    _amt.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _PhaseRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.phase != widget.phase) _name.text = widget.phase;
    if (oldWidget.amount != widget.amount) {
      _amt.text = widget.amount.toStringAsFixed(2);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: 'Phase',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) {
                final newName = v.trim();
                if (newName.isNotEmpty && newName != widget.phase) {
                  widget.ctrl.renamePhase(widget.phase, newName);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 160,
            child: TextField(
              controller: _amt,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Planned (GHS)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: (v) {
                final d = double.tryParse(v.trim());
                if (d != null && d >= 0) {
                  widget.ctrl.setPhaseAmount(widget.phase, d);
                }
              },
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => widget.ctrl.removePhase(widget.phase),
          ),
        ],
      ),
    );
  }
}
