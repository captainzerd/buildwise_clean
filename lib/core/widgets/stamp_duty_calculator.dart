import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../use_cases/calculate_stamp_duty.dart';

class StampDutyCalculator extends StatefulWidget {
  const StampDutyCalculator({super.key, this.initialValueGhs = 0});
  final double initialValueGhs;

  @override
  State<StampDutyCalculator> createState() => _StampDutyCalculatorState();
}

class _StampDutyCalculatorState extends State<StampDutyCalculator> {
  final _useCase = const CalculateStampDuty();
  final _ctrl = TextEditingController();
  bool _isCommercial = false;
  StampDutyResult? _result;
  final _fmt = NumberFormat('#,##0.00', 'en_GH');

  @override
  void initState() {
    super.initState();
    if (widget.initialValueGhs > 0) {
      _ctrl.text = widget.initialValueGhs.toStringAsFixed(0);
      _calculate();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _calculate() {
    final value = double.tryParse(_ctrl.text.replaceAll(',', ''));
    if (value == null || value <= 0) {
      setState(() => _result = null);
      return;
    }
    setState(() {
      _result = _useCase(propertyValueGhs: value, isCommercial: _isCommercial);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GRA Stamp Duty Calculator', style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Property value (GH\u20b5)',
                prefixText: 'GH\u20b5 ',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => _calculate(),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              title: const Text('Commercial property'),
              value: _isCommercial,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) {
                setState(() => _isCommercial = v ?? false);
                _calculate();
              },
            ),
            if (_result != null) ...[
              const Divider(),
              _Row('Stamp Duty (${_isCommercial ? '5%' : '3%'})',
                  'GH\u20b5 ${_fmt.format(_result!.stampDuty)}'),
              _Row('Transfer Tax (0.5%)',
                  'GH\u20b5 ${_fmt.format(_result!.transferTax)}'),
              const Divider(),
              _Row('Total payable', 'GH\u20b5 ${_fmt.format(_result!.total)}',
                  bold: true),
              _Row('CGT (15% \u2014 placeholder)',
                  'GH\u20b5 ${_fmt.format(_result!.cgtPlaceholder)}',
                  muted: true),
              const SizedBox(height: 8),
              Text(
                'These are estimates \u2014 consult a licensed solicitor.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.bold = false, this.muted = false});
  final String label;
  final String value;
  final bool bold;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.bodyMedium?.copyWith(
      fontWeight: bold ? FontWeight.bold : null,
      color: muted ? theme.colorScheme.outline : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
