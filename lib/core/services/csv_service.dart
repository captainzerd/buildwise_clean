// lib/core/services/csv_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
      ...phasesGhs.entries.map((e) => [
            'Phases',
            e.key,
            fmt(e.value),
            fmt(toFx(e.value)),
          ]),
      if (addOnsGhs.isNotEmpty)
        ...addOnsGhs.entries.map((e) => [
              'AddOns',
              e.key,
              fmt(e.value),
              fmt(toFx(e.value)),
            ]),
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
      p.join(exports.path,
          '${DateTime.now().millisecondsSinceEpoch}_${safeName.isEmpty ? "estimate" : safeName}.csv'),
    );
    await file.writeAsString(csv);
    return file.path;
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
