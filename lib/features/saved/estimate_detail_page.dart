// lib/features/saved/estimate_detail_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/snapshot.dart';
import '../../core/storage/storage_service.dart';
import '../../core/services/pdf_service.dart';

class EstimateDetailPage extends StatefulWidget {
  const EstimateDetailPage({super.key, required this.snapshot});

  final EstimateSnapshot snapshot;

  @override
  State<EstimateDetailPage> createState() => _EstimateDetailPageState();
}

class _EstimateDetailPageState extends State<EstimateDetailPage> {
  final _pdf = PdfService();
  final _storage = StorageService();

  @override
  Widget build(BuildContext context) {
    final s = widget.snapshot;
    final outs = s.outputs;
    final phases = outs['breakdownGhs'] is Map<String, dynamic>
        ? Map<String, dynamic>.from(outs['breakdownGhs'])
        : <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(
        title: Text(s.safeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: () async {
              try {
                final bytes = await _pdf.exportSnapshot(s);

                // Ensure exports folder exists under app documents.
                final docsDir = await getApplicationDocumentsDirectory();
                final exportsDir =
                    Directory('${docsDir.path}/BuildWise/exports');
                if (!await exportsDir.exists()) {
                  await exportsDir.create(recursive: true);
                }

                final outPath =
                    '${exportsDir.path}/${s.safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                await _storage.writeBytesToPath(outPath, bytes);

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF exported')),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Region: ${s.region}'),
          Text('Currency: ${s.currencyCode}'),
          Text('Saved: ${s.savedAt.toLocal()}'),
          const SizedBox(height: 12),
          Text('Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Area (m²): ${outs['areaM2Total'] ?? 0}'),
          Text(
            'Subtotal (GHS): ${outs['breakdownGhs'] != null ? phases.values.fold<num>(0, (a, b) => a + (b is num ? b : 0)).toStringAsFixed(2) : '0.00'}',
          ),
          Text('OHP (GHS): ${outs['ohpGhs'] ?? 0}'),
          Text('Contingency (GHS): ${outs['contingencyGhs'] ?? 0}'),
          Text('Taxes (GHS): ${outs['taxesGhs'] ?? 0}'),
          Text('Grand Total (GHS): ${outs['totalGhs'] ?? 0}'),
          const SizedBox(height: 16),
          if (phases.isNotEmpty) ...[
            Text('Phase breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...phases.entries.map(
              (e) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(e.key),
                trailing: Text(
                  (e.value is num)
                      ? (e.value as num).toStringAsFixed(2)
                      : e.value.toString(),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (s.transactions.isNotEmpty) ...[
            Text('Transactions',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            ...s.transactions.map(
              (t) => ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t['label']?.toString() ?? 'Transaction'),
                subtitle: Text(t['date']?.toString() ?? ''),
                trailing: Text(t['amount']?.toString() ?? ''),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
