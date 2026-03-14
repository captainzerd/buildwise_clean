import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Ghana VAT rates (as of 2024 GRA guidelines).
class GhanaVat {
  static const double vatRate = 0.15; // 15% VAT
  static const double nhilRate = 0.025; // 2.5% National Health Insurance Levy
  static const double getFundRate = 0.025; // 2.5% GETFund Levy

  static double vatAmount(double subtotal) => subtotal * vatRate;
  static double nhilAmount(double subtotal) => subtotal * nhilRate;
  static double getFundAmount(double subtotal) => subtotal * getFundRate;
  static double totalTax(double subtotal) =>
      vatAmount(subtotal) + nhilAmount(subtotal) + getFundAmount(subtotal);
  static double total(double subtotal) => subtotal + totalTax(subtotal);
}

class InvoiceLineItem {
  const InvoiceLineItem({
    required this.description,
    required this.quantity,
    required this.unitPriceGhs,
  });

  final String description;
  final double quantity;
  final double unitPriceGhs;

  double get totalGhs => quantity * unitPriceGhs;
}

class InvoiceData {
  const InvoiceData({
    required this.invoiceNumber,
    required this.issueDate,
    required this.dueDate,
    required this.issuerName,
    required this.issuerPhone,
    required this.clientName,
    required this.projectTitle,
    required this.lineItems,
    this.issuerTin,
    this.issuerAddress,
    this.clientPhone,
    this.clientAddress,
    this.notes,
  });

  final String invoiceNumber;
  final DateTime issueDate;
  final DateTime dueDate;
  final String issuerName;
  final String issuerPhone;
  final String? issuerTin;
  final String? issuerAddress;
  final String clientName;
  final String? clientPhone;
  final String? clientAddress;
  final String projectTitle;
  final List<InvoiceLineItem> lineItems;
  final String? notes;

  double get subtotal =>
      lineItems.fold<double>(0.0, (a, b) => a + b.totalGhs);
}

class InvoiceService {
  /// Generates a Ghana VAT-compliant invoice PDF and returns the bytes.
  Future<Uint8List> generatePdf(InvoiceData data) async {
    final pdf = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    final dateFmt = DateFormat('d MMM yyyy');

    final subtotal = data.subtotal;
    final vatAmt = GhanaVat.vatAmount(subtotal);
    final nhilAmt = GhanaVat.nhilAmount(subtotal);
    final getFundAmt = GhanaVat.getFundAmount(subtotal);
    final grandTotal = GhanaVat.total(subtotal);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (ctx) => [
          // ── Header ────────────────────────────────────────────────────
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TAX INVOICE',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text('Invoice No: ${data.invoiceNumber}'),
                  pw.Text(
                    'Date: ${dateFmt.format(data.issueDate)}',
                  ),
                  pw.Text(
                    'Due: ${dateFmt.format(data.dueDate)}',
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'BUILDWISE',
                    style: pw.TextStyle(
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColor.fromHex('#1565C0'),
                    ),
                  ),
                  pw.Text('Ghana Construction Management'),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 2),
          pw.SizedBox(height: 8),

          // ── Parties ──────────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'FROM',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      data.issuerName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (data.issuerAddress != null)
                      pw.Text(data.issuerAddress!),
                    pw.Text(data.issuerPhone),
                    if (data.issuerTin != null)
                      pw.Text('TIN: ${data.issuerTin}'),
                  ],
                ),
              ),
              pw.SizedBox(width: 24),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'BILL TO',
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey600,
                      ),
                    ),
                    pw.Text(
                      data.clientName,
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                    if (data.clientAddress != null)
                      pw.Text(data.clientAddress!),
                    if (data.clientPhone != null)
                      pw.Text(data.clientPhone!),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),

          // ── Project ──────────────────────────────────────────────────
          pw.Container(
            color: PdfColors.grey100,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: pw.Text(
              'Project: ${data.projectTitle}',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),

          // ── Line items ───────────────────────────────────────────────
          pw.TableHelper.fromTextArray(
            headers: ['Description', 'Qty', 'Unit Price (GHS)', 'Total (GHS)'],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.grey200,
            ),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(4),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            data: data.lineItems
                .map(
                  (item) => [
                    item.description,
                    item.quantity.toStringAsFixed(
                      item.quantity == item.quantity.toInt() ? 0 : 2,
                    ),
                    fmt.format(item.unitPriceGhs),
                    fmt.format(item.totalGhs),
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 12),

          // ── Totals ───────────────────────────────────────────────────
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 240,
              child: pw.Column(
                children: [
                  _totalRow('Subtotal', fmt.format(subtotal)),
                  _totalRow('VAT (15%)', fmt.format(vatAmt)),
                  _totalRow('NHIL (2.5%)', fmt.format(nhilAmt)),
                  _totalRow('GETFund (2.5%)', fmt.format(getFundAmt)),
                  pw.Divider(thickness: 1),
                  _totalRow(
                    'TOTAL (GHS)',
                    fmt.format(grandTotal),
                    bold: true,
                  ),
                ],
              ),
            ),
          ),

          if (data.notes != null && data.notes!.isNotEmpty) ...[
            pw.SizedBox(height: 16),
            pw.Text(
              'Notes',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(data.notes!, style: const pw.TextStyle(fontSize: 10)),
          ],

          pw.SizedBox(height: 24),
          pw.Divider(),
          pw.SizedBox(height: 8),
          pw.Text(
            'This is a computer-generated invoice. Ghana VAT Standard Rate '
            '15%, NHIL 2.5%, GETFund Levy 2.5%.',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );

    return pdf.save();
  }

  pw.Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = bold
        ? pw.TextStyle(fontWeight: pw.FontWeight.bold)
        : const pw.TextStyle();
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(value, style: style),
        ],
      ),
    );
  }
}
