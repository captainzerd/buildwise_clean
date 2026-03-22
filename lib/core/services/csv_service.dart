// lib/core/services/csv_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/cost_entry.dart';
import '../models/labor_record.dart';
import '../models/payment_record.dart';
import '../models/project.dart';

class CsvService {
  Future<String> exportBreakdown({
    required String projectName,
    required String currencyCode,
    required String currencySymbol,
    required double fxRate, // GHS -> currency
    required Map<String, double> phasesGhs,
    required Map<String, double> addOnsGhs,
    required double baseGhs,
    required double ohpGhs,
    required double contingencyGhs,
    required double taxesGhs,
    required double totalGhs,
  }) async {
    String fmt(num v) => v.toStringAsFixed(2);
    double toFx(num ghs) => ghs.toDouble() * fxRate;

    final rows = <List<String>>[
      ['Section', 'Item', 'GHS', currencyCode],
      ...phasesGhs.entries.map(
        (e) => [
          'Phases',
          e.key,
          fmt(e.value),
          fmt(toFx(e.value)),
        ],
      ),
      if (addOnsGhs.isNotEmpty)
        ...addOnsGhs.entries.map(
          (e) => [
            'AddOns',
            e.key,
            fmt(e.value),
            fmt(toFx(e.value)),
          ],
        ),
      ['Totals', 'Base', fmt(baseGhs), fmt(toFx(baseGhs))],
      ['Totals', 'OHP', fmt(ohpGhs), fmt(toFx(ohpGhs))],
      ['Totals', 'Contingency', fmt(contingencyGhs), fmt(toFx(contingencyGhs))],
      ['Totals', 'Taxes', fmt(taxesGhs), fmt(toFx(taxesGhs))],
      ['Totals', 'Grand Total', fmt(totalGhs), fmt(toFx(totalGhs))],
    ];

    final csv = const ListToCsvConverter().convert(rows);

    final dir = await getApplicationDocumentsDirectory();
    final exports = Directory(p.join(dir.path, 'exports'));
    if (!exports.existsSync()) exports.createSync(recursive: true);
    final safeName = projectName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final file = File(
      p.join(
        exports.path,
        '${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? "estimate" : safeName}.csv',
      ),
    );
    await file.writeAsString(csv);
    return file.path;
  }

  // ── Project data exports ────────────────────────────────────────────────────

  Future<File> exportCostEntries(
    List<CostEntry> entries, {
    String label = 'cost_entries',
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final rows = <List<String>>[
      ['Date', 'Category', 'Description', 'Phase ID', 'Amount (GHS)'],
      ...entries.map(
        (e) => [
          fmt.format(e.createdAt),
          e.category,
          e.description,
          e.phaseId ?? '',
          e.amountGhs.toStringAsFixed(2),
        ],
      ),
    ];
    return _writeTempCsv(
      '${label}_${DateTime.now().millisecondsSinceEpoch}.csv',
      rows,
    );
  }

  Future<File> exportPayments(
    List<PaymentRecord> payments, {
    String label = 'payments',
  }) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final rows = <List<String>>[
      [
        'Payment Date',
        'Description',
        'Direction',
        'Method',
        'Reference',
        'Amount (GHS)',
      ],
      ...payments.map(
        (pay) => [
          fmt.format(pay.paymentDate),
          pay.description,
          pay.direction.label,
          pay.method.label,
          pay.reference ?? '',
          pay.amountGhs.toStringAsFixed(2),
        ],
      ),
    ];
    return _writeTempCsv(
      '${label}_${DateTime.now().millisecondsSinceEpoch}.csv',
      rows,
    );
  }

  /// Exports labour records in a Ghana SSNIT/GRA-compatible payroll format.
  /// Columns: Date, Trade, Workers, Daily Rate (GHS), Gross Pay (GHS),
  ///          SSNIT Employer % (GHS), SSNIT Employee % (GHS),
  ///          Net Pay (GHS), Notes.
  Future<File> exportPayroll(
    List<LaborRecord> records, {
    String label = 'payroll',
    double employerSsnitRate = 0.13,
    double employeeSsnitRate = 0.055,
  }) async {
    final employerSsnit = employerSsnitRate;
    final employeeSsnit = employeeSsnitRate;
    final fmt = DateFormat('yyyy-MM-dd');
    final empPct =
        '${(employerSsnit * 100).toStringAsFixed(1)}%';
    final eePct =
        '${(employeeSsnit * 100).toStringAsFixed(1)}%';
    final rows = <List<String>>[
      [
        'Date',
        'Trade',
        'Workers',
        'Daily Rate (GHS)',
        'Gross Pay (GHS)',
        'SSNIT Employer $empPct (GHS)',
        'SSNIT Employee $eePct (GHS)',
        'Net Pay (GHS)',
        'Recorded By',
        'Notes',
      ],
      ...records.map((r) {
        final gross = r.totalGhs;
        final empContrib = gross * employerSsnit;
        final eeContrib = gross * employeeSsnit;
        final net = gross - eeContrib;
        return [
          fmt.format(r.date),
          r.tradeType.label,
          r.headcount.toString(),
          r.dailyRateGhs.toStringAsFixed(2),
          gross.toStringAsFixed(2),
          empContrib.toStringAsFixed(2),
          eeContrib.toStringAsFixed(2),
          net.toStringAsFixed(2),
          r.recordedByName,
          r.notes ?? '',
        ];
      }),
      // Totals row
      () {
        final totalGross = records.fold<double>(0, (s, r) => s + r.totalGhs);
        final totalEmp = totalGross * employerSsnit;
        final totalEe = totalGross * employeeSsnit;
        final totalNet = totalGross - totalEe;
        return [
          'TOTAL',
          '',
          records.fold<int>(0, (s, r) => s + r.headcount).toString(),
          '',
          totalGross.toStringAsFixed(2),
          totalEmp.toStringAsFixed(2),
          totalEe.toStringAsFixed(2),
          totalNet.toStringAsFixed(2),
          '',
          '',
        ];
      }(),
    ];
    return _writeTempCsv(
      '${label}_${DateTime.now().millisecondsSinceEpoch}.csv',
      rows,
    );
  }

  /// Exports a combined CSV of all projects with their costs and payments.
  /// Useful for GDPR-style "export my data" requests.
  Future<File> exportUserData(
    String uid,
    List<Project> projects,
  ) async {
    final fmt = DateFormat('yyyy-MM-dd');
    final rows = <List<String>>[
      [
        'Project ID',
        'Project Title',
        'Region',
        'Budget (GHS)',
        'Amount Spent (GHS)',
        'Status',
        'Created Date',
      ],
      ...projects.map(
        (p) => [
          p.id,
          p.title,
          p.region,
          p.budget.toStringAsFixed(2),
          p.amountSpent.toStringAsFixed(2),
          p.status.label,
          fmt.format(p.createdAt),
        ],
      ),
    ];
    return _writeTempCsv(
      'userdata_${uid}_${DateTime.now().millisecondsSinceEpoch}.csv',
      rows,
    );
  }

  Future<File> _writeTempCsv(
    String filename,
    List<List<String>> rows,
  ) async {
    final csv = const ListToCsvConverter().convert(rows);
    final dir = await getApplicationDocumentsDirectory();
    final exports = Directory(p.join(dir.path, 'exports'));
    if (!exports.existsSync()) exports.createSync(recursive: true);
    final file = File(p.join(exports.path, filename));
    await file.writeAsString(csv);
    return file;
  }
}

/// Minimal CSV writer with quoting; avoids adding an external package.
class ListToCsvConverter {
  const ListToCsvConverter();

  String convert(List<List<String>> rows) {
    return rows.map(_toLine).join('\n');
  }

  String _toLine(List<String> fields) {
    return fields.map(_quote).join(',');
  }

  String _quote(String s) {
    final needs = s.contains(',') || s.contains('"') || s.contains('\n');
    final escaped = s.replaceAll('"', '""');
    return needs ? '"$escaped"' : escaped;
  }
}
