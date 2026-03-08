// lib/features/estimate/boq_page.dart
//
// Displays the generated Bill of Quantities in a scrollable table and allows
// the user to export it as a CSV file.

import 'dart:io';

import 'package:csv/csv.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;

import '../../core/models/boq_item.dart';
import '../../core/services/boq_service.dart';
import '../../core/services/pdf_service.dart';

class BoqPage extends StatefulWidget {
  const BoqPage({
    super.key,
    this.phaseBreakdown,
    required this.floorAreaSqm,
    required this.boqService,
    this.precomputedItems,
    this.projectName,
  });

  /// Phase breakdown map used to generate items on the fly.
  /// Not needed when [precomputedItems] is provided.
  final Map<String, double>? phaseBreakdown;
  final double floorAreaSqm;
  final BoqService boqService;

  /// When provided these items are used directly, bypassing generation.
  /// This preserves the BOQ that was frozen at save/creation time.
  final List<BoqItem>? precomputedItems;
  final String? projectName;

  @override
  State<BoqPage> createState() => _BoqPageState();
}

class _BoqPageState extends State<BoqPage> {
  late final List<BoqItem> _items;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _items = widget.precomputedItems ??
        widget.boqService.generate(
          phaseBreakdown: widget.phaseBreakdown ?? {},
          floorAreaSqm: widget.floorAreaSqm,
        );
  }

  Future<void> _exportCsv() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final rows = <List<dynamic>>[
        ['Phase', 'Description', 'Unit', 'Quantity', 'Unit Rate (GHS)', 'Total (GHS)'],
        ..._items.map(
          (it) => [
            it.phase,
            it.description,
            it.unit,
            it.quantity,
            it.unitRateGhs.toStringAsFixed(2),
            it.totalGhs.toStringAsFixed(2),
          ],
        ),
        // Grand total row
        ['', '', '', '', 'GRAND TOTAL',
          _items.fold<double>(0, (s, e) => s + e.totalGhs).toStringAsFixed(2),],
      ];

      final csv = const ListToCsvConverter().convert(rows);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/boq_export.csv');
      await file.writeAsString(csv);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Indicative Quantity Schedule',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final bytes = await PdfService().generateBoqPdf(
        projectName: widget.projectName,
        floorAreaSqm: widget.floorAreaSqm,
        items: _items,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'BOQ${widget.projectName != null ? "_${widget.projectName}" : ""}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _showHelp(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Indicative Quantity Schedule',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...[
              'The IQS lists every material and labour item needed to complete the project.',
              'Unit rates are sourced from the Ghana cost catalog and adjusted for your region.',
              'Export as CSV to share with contractors for competitive quoting.',
              'Export as PDF to attach to tender documents or client presentations.',
              'Quantities are calculated from your floor area (m²) entered during estimation.',
            ].map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(fontSize: 16)),
                    Expanded(child: Text(tip)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    final grandTotal = _items.fold<double>(0, (s, e) => s + e.totalGhs);

    // Group items by phase for section headers
    final phases = _items.map((e) => e.phase).toSet().toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Indicative Quantity Schedule'),
        actions: [
          IconButton(
            tooltip: 'Help',
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelp(context),
          ),
          if (_exporting)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<_ExportFormat>(
              icon: const Icon(Icons.download_outlined),
              tooltip: 'Export',
              onSelected: (fmt) {
                if (fmt == _ExportFormat.csv) _exportCsv();
                if (fmt == _ExportFormat.pdf) _exportPdf();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: _ExportFormat.csv,
                  child: ListTile(
                    leading: Icon(Icons.table_chart_outlined),
                    title: Text('Export CSV'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: _ExportFormat.pdf,
                  child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Export PDF'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Disclaimer banner
          Container(
            margin: const EdgeInsets.fromLTRB(0, 0, 0, 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    color: Theme.of(context).colorScheme.error, size: 18,),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'INDICATIVE ONLY — Quantities are estimated from floor area geometry, '
                    'not measured from drawings. This schedule is NOT a substitute for a '
                    'Bill of Quantities prepared by a Licensed Quantity Surveyor.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Summary card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Grand Total',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        'GH₵ ${fmt.format(grandTotal)}',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Floor area',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Text(
                        '${widget.floorAreaSqm.toStringAsFixed(0)} m²',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Per-phase tables
          for (final phase in phases) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                phase,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            _BoqTable(
              items: _items.where((e) => e.phase == phase).toList(),
              fmt: fmt,
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _BoqTable extends StatelessWidget {
  const _BoqTable({required this.items, required this.fmt});

  final List<BoqItem> items;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStatePropertyAll(
            cs.primaryContainer.withValues(alpha: 0.4),
          ),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Unit')),
            DataColumn(label: Text('Qty'), numeric: true),
            DataColumn(label: Text('Rate (GHS)'), numeric: true),
            DataColumn(label: Text('Total (GHS)'), numeric: true),
          ],
          rows: [
            for (final item in items)
              DataRow(
                cells: [
                  DataCell(
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: Text(item.description),
                    ),
                  ),
                  DataCell(Text(item.unit)),
                  DataCell(Text(fmt.format(item.quantity))),
                  DataCell(Text(fmt.format(item.unitRateGhs))),
                  DataCell(
                    Text(
                      fmt.format(item.totalGhs),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            // Phase sub-total row
            DataRow(
              color: WidgetStatePropertyAll(
                cs.surfaceContainerHighest.withValues(alpha: 0.6),
              ),
              cells: [
                const DataCell(Text('Sub-total', style: TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                const DataCell(Text('')),
                const DataCell(Text('')),
                DataCell(
                  Text(
                    'GH₵ ${fmt.format(items.fold<double>(0, (s, e) => s + e.totalGhs))}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ExportFormat { csv, pdf }
