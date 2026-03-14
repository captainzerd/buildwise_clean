// lib/utils/csv_exporter.dart
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Minimal CSV builder for the estimate detail screen.
class CsvExporter {
  static Future<String> export({
    required String projectName,
    required String displayCode, // e.g., "USD" or "GHS"
    required double Function(double ghs) convert, // convert GHS -> display
    required Map<String, double> breakdownGhs,
    required Map<String, double> addonsGhs,
    required double ohpGhs,
    required double contingencyGhs,
    required double taxesGhs,
    required double totalGhs,
  }) async {
    final lines = <String>[];
    lines.add('Phase,Amount(GHS),Amount($displayCode)');

    double fx(double v) => convert(v);

    breakdownGhs.forEach((k, v) {
      lines.add('$k,${v.toStringAsFixed(2)},${fx(v).toStringAsFixed(2)}');
    });

    addonsGhs.forEach((k, v) {
      lines.add('AddOn:$k,${v.toStringAsFixed(2)},${fx(v).toStringAsFixed(2)}');
    });

    lines.add(
        'OHP,${ohpGhs.toStringAsFixed(2)},${fx(ohpGhs).toStringAsFixed(2)}',);
    lines.add(
        'Contingency,${contingencyGhs.toStringAsFixed(2)},${fx(contingencyGhs).toStringAsFixed(2)}',);
    lines.add(
        'Taxes,${taxesGhs.toStringAsFixed(2)},${fx(taxesGhs).toStringAsFixed(2)}',);
    lines.add(
        'Total,${totalGhs.toStringAsFixed(2)},${fx(totalGhs).toStringAsFixed(2)}',);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/buildwise_${_safe(projectName)}.csv');
    await file.writeAsString(lines.join('\n'), flush: true);
    return file.path;
  }

  static String _safe(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_').replaceAll(
          RegExp(r'^_|_$'), '',); // <-- raw string so $ isn't interpolation
}
