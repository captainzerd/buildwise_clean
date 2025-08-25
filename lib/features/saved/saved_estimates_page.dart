// lib/features/saved/saved_estimates_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/services/pdf_service.dart';
import '../../core/services/snapshot.dart';
import '../../core/storage/storage_service.dart';
import 'estimate_detail_page.dart';

class SavedEstimatesPage extends StatefulWidget {
  const SavedEstimatesPage({super.key});

  @override
  State<SavedEstimatesPage> createState() => _SavedEstimatesPageState();
}

class _SavedEstimatesPageState extends State<SavedEstimatesPage> {
  final _storage = StorageService();
  final _pdf = PdfService();

  late Future<List<EstimateSnapshot>> _futureSnaps;

  @override
  void initState() {
    super.initState();
    _futureSnaps = _load();
  }

  Future<List<EstimateSnapshot>> _load() async {
    final paths = await _storage.listJsonPaths(subFolder: 'estimates');
    final snaps = <EstimateSnapshot>[];
    for (final path in paths) {
      try {
        final map = await _storage.readJsonAtPath(path);
        final snap = EstimateSnapshot.fromJson(map);
        snaps.add(snap);
      } catch (_) {
        // ignore corrupted file; continue
      }
    }
    return snaps;
  }

  Future<void> _exportPdf(EstimateSnapshot snap) async {
    final bytes = await _pdf.exportSnapshot(snap);
    final docs = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${docs.path}/BuildWise/exports');
    if (!await exportsDir.exists()) {
      await exportsDir.create(recursive: true);
    }
    final outPath =
        '${exportsDir.path}/${snap.safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    await _storage.writeBytesToPath(outPath, bytes);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Exported: ${snap.safeName}.pdf')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Estimates')),
      body: FutureBuilder<List<EstimateSnapshot>>(
        future: _futureSnaps,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No saved estimates yet.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final s = items[i];
              return ListTile(
                title: Text(s.safeName),
                subtitle: Text(
                  '${s.region} • ${s.currencyCode} • ${s.savedAt.toLocal()}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: 'Export PDF',
                  onPressed: () => _exportPdf(s),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EstimateDetailPage(snapshot: s),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
