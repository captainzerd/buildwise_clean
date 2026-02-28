// lib/core/services/pdf_service.dart
//
// Unicode-safe PDF export for EstimateSnapshot and ProjectReportData.
// Embeds Noto Sans fonts to support "₵" (U+20B5) and "—" (U+2014).
// Provides: exportSnapshot(snap) -> Uint8List
//           exportEstimate(snap) -> alias
//           generateProjectReport(data) -> Uint8List

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../models/cost_entry.dart';
import '../models/payment_record.dart';
import '../models/phase.dart';
import '../models/project.dart';
import 'snapshot.dart';

class ProjectReportData {
  const ProjectReportData({
    required this.project,
    required this.phases,
    required this.costs,
    required this.payments,
  });

  final Project project;
  final List<Phase> phases;
  final List<CostEntry> costs;
  final List<PaymentRecord> payments;
}

class PdfService {
  Future<pw.Font> _loadFont(String assetPath) async {
    final data = await rootBundle.load(assetPath);
    return pw.Font.ttf(data);
  }

  Future<(pw.Font regular, pw.Font bold)> _loadFonts() async {
    try {
      final regular = await _loadFont('assets/fonts/NotoSans-Regular.ttf');
      final bold = await _loadFont('assets/fonts/NotoSans-Bold.ttf');
      return (regular, bold);
    } catch (_) {
      final fallback = pw.Font.helvetica();
      final fallbackBold = pw.Font.helveticaBold();
      return (fallback, fallbackBold);
    }
  }

  String _symbolFor(String code) {
    switch (code.toUpperCase()) {
      case 'GHS':
        return '₵';
      case 'USD':
        return r'$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'NGN':
        return '₦';
      case 'ZAR':
        return 'R';
      default:
        return code.toUpperCase();
    }
  }

  String _fmtMoney(num v, {String? code}) {
    final s = v.toStringAsFixed(2);
    return code == null ? s : '${_symbolFor(code)} $s';
  }

  double _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  pw.Widget _row(String label, String value, pw.TextStyle style) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Expanded(child: pw.Text(label, style: style)),
        pw.Text(value, style: style),
      ],
    );
  }

  pw.Widget _section(
    String title,
    List<pw.Widget> children,
    pw.TextStyle hStyle,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: hStyle),
        pw.SizedBox(height: 6),
        ...children,
      ],
    );
  }

  Future<Uint8List> exportSnapshot(EstimateSnapshot snap) async {
    final (regular, bold) = await _loadFonts();
    final doc = pw.Document();

    final baseText = pw.TextStyle(font: regular, fontFallback: [regular]);
    final h1 = baseText.copyWith(font: bold, fontSize: 18);
    final h2 = baseText.copyWith(font: bold, fontSize: 14);
    final body = baseText.copyWith(fontSize: 11);

    final outs = snap.outputs;

    final total = _asDouble(outs['totalGhs']);
    final baseCost = _asDouble(
      outs['breakdownGhs'] != null
          ? (outs['breakdownGhs'] as Map)
              .values
              .fold<num>(0, (a, b) => a + _asDouble(b))
          : 0,
    );
    final ohp = _asDouble(outs['ohpGhs']);
    final contingency = _asDouble(outs['contingencyGhs']);
    final taxes = _asDouble(outs['taxesGhs']);
    final area = _asDouble(outs['areaM2Total']);

    final fx = outs['fx'] is Map
        ? Map<String, dynamic>.from(outs['fx'])
        : <String, dynamic>{};
    final code = (fx['code'] ?? snap.currencyCode).toString();

    pw.Widget breakdownTable() {
      final b = outs['breakdownGhs'] is Map
          ? Map<String, dynamic>.from(outs['breakdownGhs'])
          : <String, dynamic>{};
      final rows = b.entries
          .map(
            (e) => pw.TableRow(
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(e.key, style: body),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      _fmtMoney(_asDouble(e.value), code: 'GHS'),
                      style: body,
                    ),
                  ),
                ),
              ],
            ),
          )
          .toList();

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
            children: [
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Text('Phase', style: body.copyWith(font: bold)),
              ),
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 6),
                child: pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child:
                      pw.Text('Amount (GHS)', style: body.copyWith(font: bold)),
                ),
              ),
            ],
          ),
          ...rows,
        ],
      );
    }

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(24),
        build: (ctx) => [
          pw.Text('Estimate — ${snap.safeName}', style: h1),
          pw.SizedBox(height: 3),
          pw.Text(
            'Saved: ${snap.savedAt.toLocal()}   Region: ${snap.region}   Currency: ${snap.currencyCode}',
            style: body,
          ),
          pw.SizedBox(height: 12),
          _section(
            'Summary',
            [
              _row(
                'Total Built-up Area',
                '${area.toStringAsFixed(2)} m²',
                body,
              ),
              _row(
                'Works Subtotal (GHS)',
                _fmtMoney(baseCost, code: 'GHS'),
                body,
              ),
              _row(
                'Overheads & Profit (GHS)',
                _fmtMoney(ohp, code: 'GHS'),
                body,
              ),
              _row(
                'Contingency (GHS)',
                _fmtMoney(contingency, code: 'GHS'),
                body,
              ),
              _row('Taxes (GHS)', _fmtMoney(taxes, code: 'GHS'), body),
              pw.Divider(color: PdfColors.grey500, thickness: 0.5),
              _row(
                'Grand Total (GHS)',
                _fmtMoney(total, code: 'GHS'),
                body.copyWith(font: bold),
              ),
            ],
            h2,
          ),
          pw.SizedBox(height: 14),
          _section('Phase Breakdown', [breakdownTable()], h2),
          pw.SizedBox(height: 14),
          if (fx.isNotEmpty)
            _section(
              'Converted Total',
              [
                _row(
                  'Grand Total',
                  _fmtMoney(_asDouble(fx['total']), code: code),
                  body.copyWith(font: bold),
                ),
                pw.Text(
                  'Rate basis: 1 GHS → ${_symbolFor(code)} ${_asDouble(fx['rate']).toStringAsFixed(6)}',
                  style: body,
                ),
              ],
              h2,
            ),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> exportEstimate(EstimateSnapshot snap) =>
      exportSnapshot(snap);

  // ── Project Report ────────────────────────────────────────────────────────

  pw.Widget _cellPad(pw.Widget child) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: child,
      );

  String _fmtDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day.toString().padLeft(2, '0')} ${months[d.month - 1]} ${d.year}';
  }

  Future<Uint8List> generateProjectReport(ProjectReportData data) async {
    final (regular, bold) = await _loadFonts();
    final doc = pw.Document();

    final baseText = pw.TextStyle(font: regular, fontFallback: [regular]);
    final h1 = baseText.copyWith(font: bold, fontSize: 18);
    final h2 = baseText.copyWith(font: bold, fontSize: 13);
    final body = baseText.copyWith(fontSize: 10);
    final bodyBold = body.copyWith(font: bold);

    final project = data.project;
    final phases = List<Phase>.from(data.phases)
      ..sort((a, b) => a.order.compareTo(b.order));
    final costs = data.costs;
    final payments = data.payments;

    // Budget
    final budget = project.budget;
    final spent = project.amountSpent;
    final remaining = budget - spent;
    final progress = budget > 0 ? (spent / budget).clamp(0.0, 1.0) : 0.0;

    // Costs by category
    final Map<String, double> categoryTotals = {};
    for (final c in costs) {
      categoryTotals[c.category] =
          (categoryTotals[c.category] ?? 0) + c.amountGhs;
    }
    final totalCosts = categoryTotals.values.fold(0.0, (a, b) => a + b);
    final sortedCategories = categoryTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Recent payments (last 10 by payment date)
    final recentPayments =
        (List<PaymentRecord>.from(payments)
              ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)))
            .take(10)
            .toList();

    // Progress bar
    pw.Widget progressBar(double p) {
      final filled = (p * 100).round().clamp(0, 100);
      final empty = 100 - filled;
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            height: 8,
            child: pw.Row(
              children: [
                if (filled > 0)
                  pw.Expanded(
                    flex: filled,
                    child: pw.Container(color: PdfColors.blue700),
                  ),
                if (empty > 0)
                  pw.Expanded(
                    flex: empty,
                    child: pw.Container(color: PdfColors.grey200),
                  ),
              ],
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text('${(p * 100).toStringAsFixed(1)}% spent', style: body),
        ],
      );
    }

    // Helper: right-aligned cell
    pw.Widget rightCell(String text, pw.TextStyle style) => _cellPad(
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(text, style: style),
          ),
        );

    // Phases table
    pw.Widget phasesTable() {
      final hStyle = body.copyWith(font: bold);
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: const {
          0: pw.FixedColumnWidth(24),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(2),
          3: pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
            children: [
              _cellPad(pw.Text('#', style: hStyle)),
              _cellPad(pw.Text('Phase', style: hStyle)),
              _cellPad(pw.Text('Status', style: hStyle)),
              rightCell('Est. Cost (GHS)', hStyle),
            ],
          ),
          for (int i = 0; i < phases.length; i++)
            pw.TableRow(
              children: [
                _cellPad(pw.Text('${i + 1}', style: body)),
                _cellPad(pw.Text(phases[i].name, style: body)),
                _cellPad(pw.Text(phases[i].status.label, style: body)),
                rightCell(
                  phases[i].estimatedCostGhs != null
                      ? _fmtMoney(phases[i].estimatedCostGhs!, code: 'GHS')
                      : '\u2014',
                  body,
                ),
              ],
            ),
        ],
      );
    }

    // Costs by category table
    pw.Widget costsTable() {
      final hStyle = body.copyWith(font: bold);
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: const {
          0: pw.FlexColumnWidth(3),
          1: pw.FlexColumnWidth(2),
          2: pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
            children: [
              _cellPad(pw.Text('Category', style: hStyle)),
              rightCell('Total (GHS)', hStyle),
              rightCell('%', hStyle),
            ],
          ),
          for (final entry in sortedCategories)
            pw.TableRow(
              children: [
                _cellPad(pw.Text(entry.key, style: body)),
                rightCell(_fmtMoney(entry.value, code: 'GHS'), body),
                rightCell(
                  totalCosts > 0
                      ? '${(entry.value / totalCosts * 100).toStringAsFixed(1)}%'
                      : '\u2014',
                  body,
                ),
              ],
            ),
        ],
      );
    }

    // Payments table
    pw.Widget paymentsTable() {
      final hStyle = body.copyWith(font: bold);
      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: const {
          0: pw.FixedColumnWidth(60),
          1: pw.FlexColumnWidth(3),
          2: pw.FlexColumnWidth(1.5),
          3: pw.FlexColumnWidth(1.5),
          4: pw.FlexColumnWidth(2),
        },
        children: [
          pw.TableRow(
            decoration:
                const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
            children: [
              _cellPad(pw.Text('Date', style: hStyle)),
              _cellPad(pw.Text('Description', style: hStyle)),
              _cellPad(pw.Text('Direction', style: hStyle)),
              _cellPad(pw.Text('Method', style: hStyle)),
              rightCell('Amount (GHS)', hStyle),
            ],
          ),
          for (final p in recentPayments)
            pw.TableRow(
              children: [
                _cellPad(pw.Text(_fmtDate(p.paymentDate), style: body)),
                _cellPad(pw.Text(p.description, style: body)),
                _cellPad(pw.Text(p.direction.label, style: body)),
                _cellPad(pw.Text(p.method.label, style: body)),
                rightCell(_fmtMoney(p.amountGhs, code: 'GHS'), body),
              ],
            ),
        ],
      );
    }

    final footerStyle = body.copyWith(color: PdfColors.grey500, fontSize: 9);

    doc.addPage(
      pw.MultiPage(
        margin: const pw.EdgeInsets.all(28),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Generated ${_fmtDate(DateTime.now())}  \u2022  BuildWise',
              style: footerStyle,
            ),
            pw.Text(
              '${ctx.pageNumber} / ${ctx.pagesCount}',
              style: footerStyle,
            ),
          ],
        ),
        build: (ctx) => [
          // ── Header ─────────────────────────────────────────────────────────
          pw.Text('Project Report: ${project.title}', style: h1),
          pw.SizedBox(height: 4),
          pw.Row(
            children: [
              pw.Text('Status: ', style: bodyBold),
              pw.Text(project.status.label, style: body),
              if (project.region.isNotEmpty) ...[
                pw.SizedBox(width: 16),
                pw.Text('Region: ', style: bodyBold),
                pw.Text(project.region, style: body),
              ],
            ],
          ),
          if (project.location != null && project.location!.isNotEmpty)
            pw.Text('Location: ${project.location}', style: body),
          pw.Text('Created: ${_fmtDate(project.createdAt)}', style: body),
          pw.SizedBox(height: 16),

          // ── Budget Summary ──────────────────────────────────────────────────
          _section(
            'Budget Summary',
            [
              _row('Budget (GHS)', _fmtMoney(budget, code: 'GHS'), body),
              _row('Amount Spent (GHS)', _fmtMoney(spent, code: 'GHS'), body),
              pw.Divider(color: PdfColors.grey400, thickness: 0.4),
              _row(
                remaining >= 0 ? 'Remaining (GHS)' : 'Over Budget (GHS)',
                _fmtMoney(remaining.abs(), code: 'GHS'),
                remaining >= 0 ? body : body.copyWith(color: PdfColors.red700),
              ),
              if (budget > 0) ...[
                pw.SizedBox(height: 6),
                progressBar(progress),
              ],
            ],
            h2,
          ),
          pw.SizedBox(height: 16),

          // ── Phases ─────────────────────────────────────────────────────────
          if (phases.isNotEmpty) ...[
            _section('Phases (${phases.length})', [phasesTable()], h2),
            pw.SizedBox(height: 16),
          ],

          // ── Costs by Category ───────────────────────────────────────────────
          if (sortedCategories.isNotEmpty) ...[
            _section('Costs by Category', [costsTable()], h2),
            pw.SizedBox(height: 16),
          ],

          // ── Recent Payments ─────────────────────────────────────────────────
          if (recentPayments.isNotEmpty)
            _section(
              payments.length > 10
                  ? 'Recent Payments (last 10 of ${payments.length})'
                  : 'Payments (${payments.length})',
              [paymentsTable()],
              h2,
            ),
        ],
      ),
    );

    return doc.save();
  }
}
