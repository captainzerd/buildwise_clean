// lib/core/services/pdf_service.dart
//
// Unicode-safe PDF export for EstimateSnapshot.
// Embeds Noto Sans fonts to support "₵" (U+20B5) and "—" (U+2014).
// Provides: exportSnapshot(snap) -> Uint8List
//           exportEstimate(snap) -> alias

import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import 'snapshot.dart';

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
      String title, List<pw.Widget> children, pw.TextStyle hStyle) {
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
    final baseCost = _asDouble(outs['breakdownGhs'] != null
        ? (outs['breakdownGhs'] as Map)
            .values
            .fold<num>(0, (a, b) => a + _asDouble(b))
        : 0);
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
          .map((e) => pw.TableRow(children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Text(e.key, style: body),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(_fmtMoney(_asDouble(e.value), code: 'GHS'),
                        style: body),
                  ),
                ),
              ]))
          .toList();

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.4),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(1)
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
              style: body),
          pw.SizedBox(height: 12),
          _section(
              'Summary',
              [
                _row('Total Built-up Area', '${area.toStringAsFixed(2)} m²',
                    body),
                _row('Works Subtotal (GHS)', _fmtMoney(baseCost, code: 'GHS'),
                    body),
                _row('Overheads & Profit (GHS)', _fmtMoney(ohp, code: 'GHS'),
                    body),
                _row('Contingency (GHS)', _fmtMoney(contingency, code: 'GHS'),
                    body),
                _row('Taxes (GHS)', _fmtMoney(taxes, code: 'GHS'), body),
                pw.Divider(color: PdfColors.grey500, thickness: 0.5),
                _row('Grand Total (GHS)', _fmtMoney(total, code: 'GHS'),
                    body.copyWith(font: bold)),
              ],
              h2),
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
                      body.copyWith(font: bold)),
                  pw.Text(
                      'Rate basis: 1 GHS → ${_symbolFor(code)} ${_asDouble(fx['rate']).toStringAsFixed(6)}',
                      style: body),
                ],
                h2),
        ],
      ),
    );

    return doc.save();
  }

  Future<Uint8List> exportEstimate(EstimateSnapshot snap) =>
      exportSnapshot(snap);
}
