// lib/features/estimate/widgets/mortgage_calculator_sheet.dart
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// ── Ghana bank rate data (hardcoded for MVP — Q1 2026) ───────────────────────

class _GhanaBankRate {
  const _GhanaBankRate({
    required this.bankName,
    required this.minRatePercent,
    required this.maxRatePercent,
    required this.maxTermYears,
  });

  final String bankName;
  final double minRatePercent;
  final double maxRatePercent;
  final int maxTermYears;
}

const _ghanaRates = [
  _GhanaBankRate(
    bankName: 'GCB Bank',
    minRatePercent: 28.0,
    maxRatePercent: 32.0,
    maxTermYears: 20,
  ),
  _GhanaBankRate(
    bankName: 'Absa Ghana',
    minRatePercent: 27.0,
    maxRatePercent: 31.0,
    maxTermYears: 25,
  ),
  _GhanaBankRate(
    bankName: 'Ecobank Ghana',
    minRatePercent: 28.5,
    maxRatePercent: 33.0,
    maxTermYears: 20,
  ),
  _GhanaBankRate(
    bankName: 'Fidelity Bank',
    minRatePercent: 29.0,
    maxRatePercent: 34.0,
    maxTermYears: 15,
  ),
  _GhanaBankRate(
    bankName: 'Standard Chartered',
    minRatePercent: 26.5,
    maxRatePercent: 30.5,
    maxTermYears: 25,
  ),
  _GhanaBankRate(
    bankName: 'Stanbic Bank',
    minRatePercent: 27.5,
    maxRatePercent: 31.5,
    maxTermYears: 20,
  ),
];

// ── Widget ────────────────────────────────────────────────────────────────────

class MortgageCalculatorSheet extends StatefulWidget {
  const MortgageCalculatorSheet({
    super.key,
    this.initialLoanAmountGhs,
  });

  /// Pre-filled from the estimate total or project budget (GHS).
  final double? initialLoanAmountGhs;

  @override
  State<MortgageCalculatorSheet> createState() =>
      _MortgageCalculatorSheetState();
}

class _MortgageCalculatorSheetState extends State<MortgageCalculatorSheet> {
  final _amountCtrl = TextEditingController();
  final _nf = NumberFormat('#,##0.00', 'en_GH');
  final _intFmt = NumberFormat('#,##0', 'en_GH');

  double _loanAmount = 0;
  double _downPaymentPct = 20;
  int _termYears = 20;
  double _annualRate = 28.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialLoanAmountGhs != null &&
        widget.initialLoanAmountGhs! > 0) {
      _loanAmount = widget.initialLoanAmountGhs!;
      _amountCtrl.text = _intFmt.format(_loanAmount);
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  // ── Calculation ─────────────────────────────────────────────────────────────

  double get _principal => _loanAmount * (1 - _downPaymentPct / 100);

  /// Monthly payment using standard amortisation formula.
  /// M = P * r * (1+r)^n / ((1+r)^n - 1)
  double? get _monthlyPayment {
    final p = _principal;
    if (p <= 0 || _annualRate <= 0 || _termYears <= 0) return null;
    final r = _annualRate / 12 / 100;
    final n = _termYears * 12;
    final rn = pow(1 + r, n);
    return p * r * rn / (rn - 1);
  }

  double? get _totalRepayable {
    final m = _monthlyPayment;
    if (m == null) return null;
    return m * _termYears * 12;
  }

  double? get _totalInterest {
    final total = _totalRepayable;
    if (total == null) return null;
    return total - _principal;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _onAmountChanged(String value) {
    final cleaned = value.replaceAll(',', '').replaceAll(' ', '');
    setState(() {
      _loanAmount = double.tryParse(cleaned) ?? 0;
    });
  }

  String _fmtGhs(double? amount) {
    if (amount == null || amount.isNaN || amount.isInfinite) return '—';
    return 'GHS ${_nf.format(amount)}';
  }

  // ── UI ───────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) => Column(
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 20),
                  _buildLoanAmountField(context),
                  const SizedBox(height: 20),
                  _buildDownPaymentSlider(context),
                  const SizedBox(height: 20),
                  _buildTermSelector(context),
                  const SizedBox(height: 20),
                  _buildRateSlider(context),
                  const SizedBox(height: 24),
                  _buildResultsCard(context),
                  const SizedBox(height: 24),
                  _buildRatesTable(context),
                  const SizedBox(height: 16),
                  Text(
                    'Rates as at Q1 2026. Subject to bank approval.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calculate_outlined, color: cs.primary),
            const SizedBox(width: 10),
            Text(
              'Mortgage Calculator',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: cs.onTertiaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Rates are indicative — consult your bank for a formal quote.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoanAmountField(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Property / Loan Amount',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _amountCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
          ],
          decoration: InputDecoration(
            prefixText: 'GHS ',
            hintText: '0',
            border: const OutlineInputBorder(),
            helperText: _loanAmount > 0
                ? 'Loan principal: ${_fmtGhs(_principal)}'
                : null,
          ),
          onChanged: _onAmountChanged,
        ),
      ],
    );
  }

  Widget _buildDownPaymentSlider(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Down payment', style: theme.textTheme.labelLarge),
            Text(
              '${_downPaymentPct.toInt()}%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _downPaymentPct,
          min: 5,
          max: 50,
          divisions: 9, // steps of 5
          label: '${_downPaymentPct.toInt()}%',
          onChanged: (v) => setState(() => _downPaymentPct = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('5%', style: theme.textTheme.bodySmall),
            Text('50%', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildTermSelector(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Loan term (years)', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 10, label: Text('10')),
            ButtonSegment(value: 15, label: Text('15')),
            ButtonSegment(value: 20, label: Text('20')),
            ButtonSegment(value: 25, label: Text('25')),
          ],
          selected: {_termYears},
          onSelectionChanged: (s) => setState(() => _termYears = s.first),
        ),
      ],
    );
  }

  Widget _buildRateSlider(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Annual interest rate', style: theme.textTheme.labelLarge),
            Text(
              '${_annualRate.toStringAsFixed(1)}%',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: _annualRate,
          min: 20,
          max: 40,
          divisions: 40, // steps of 0.5
          label: '${_annualRate.toStringAsFixed(1)}%',
          onChanged: (v) => setState(() => _annualRate = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('20%', style: theme.textTheme.bodySmall),
            Text('40%', style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }

  Widget _buildResultsCard(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Card(
      color: cs.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Estimated Repayments',
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Divider(height: 20),
            _ResultRow(
              label: 'Monthly repayment',
              value: _fmtGhs(_monthlyPayment),
              highlighted: true,
              textTheme: theme.textTheme,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(height: 12),
            _ResultRow(
              label: 'Total repayable',
              value: _fmtGhs(_totalRepayable),
              textTheme: theme.textTheme,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            _ResultRow(
              label: 'Total interest',
              value: _fmtGhs(_totalInterest),
              textTheme: theme.textTheme,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(height: 8),
            _ResultRow(
              label: 'Principal borrowed',
              value: _fmtGhs(_principal > 0 ? _principal : null),
              textTheme: theme.textTheme,
              color: cs.onPrimaryContainer,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatesTable(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Ghana Bank Indicative Rates',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Table(
            columnWidths: const {
              0: FlexColumnWidth(2.2),
              1: FlexColumnWidth(1.8),
              2: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(color: cs.surfaceContainerHighest),
                children: [
                  _tableHeader('Bank', theme),
                  _tableHeader('Rate (p.a.)', theme),
                  _tableHeader('Max Term', theme),
                ],
              ),
              for (final rate in _ghanaRates)
                TableRow(
                  decoration: BoxDecoration(
                    color: cs.surface,
                    border: Border(
                      bottom: BorderSide(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  children: [
                    _tableCell(rate.bankName, theme),
                    _tableCell(
                      '${rate.minRatePercent.toStringAsFixed(1)} – '
                      '${rate.maxRatePercent.toStringAsFixed(1)}%',
                      theme,
                    ),
                    _tableCell('${rate.maxTermYears} yrs', theme),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tableHeader(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          text,
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      );

  Widget _tableCell(String text, ThemeData theme) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(text, style: theme.textTheme.bodySmall),
      );
}

// ── Helper widgets ────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.value,
    required this.textTheme,
    required this.color,
    this.highlighted = false,
  });

  final String label;
  final String value;
  final TextTheme textTheme;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: highlighted
              ? textTheme.bodyMedium?.copyWith(color: color)
              : textTheme.bodySmall?.copyWith(color: color.withValues(alpha: 0.8)),
        ),
        Text(
          value,
          style: highlighted
              ? textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                )
              : textTheme.bodyMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
        ),
      ],
    );
  }
}
