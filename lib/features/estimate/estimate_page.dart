// lib/features/estimate/estimate_page.dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../core/services/pdf_service.dart';
import '../../core/storage/storage_service.dart';
import '../saved/saved_estimates_page.dart';
import 'state/estimate_controller.dart';
import 'widgets/estimate_body.dart';

class EstimatePage extends StatelessWidget {
  const EstimatePage({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = context.watch<EstimateController>();
    final pdf = PdfService();
    final storage = StorageService();

    Future<void> exportPdf() async {
      if (!ctrl.hasResult) return;

      try {
        // If your controller exposes `toSnapshot()`, this will work as-is.
        // If not, keep this call and I’ll ship the controller’s `toSnapshot()` next.
        final snap = ctrl.toSnapshot();

        final bytes = await pdf.exportSnapshot(snap);

        // Ensure export directory exists
        final docs = await getApplicationDocumentsDirectory();
        final exportsDir = Directory('${docs.path}/BuildWise/exports');
        if (!await exportsDir.exists()) {
          await exportsDir.create(recursive: true);
        }

        final outPath =
            '${exportsDir.path}/${snap.safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
        await storage.writeBytesToPath(outPath, bytes);

        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF exported: ${snap.safeName}')),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }

    Future<void> saveEstimate() async {
      if (!ctrl.hasResult) return;
      try {
        final path = await ctrl.saveSnapshot();
        if (!context.mounted) return;
        if (path != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Estimate saved')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nothing to save yet')),
          );
        }
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('BuildWise — Estimate'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.save_outlined),
            onPressed: ctrl.hasResult ? saveEstimate : null,
          ),
          IconButton(
            tooltip: 'Export PDF',
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: ctrl.hasResult ? exportPdf : null,
          ),
          IconButton(
            tooltip: 'Saved',
            icon: const Icon(Icons.folder_open_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SavedEstimatesPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: const EstimateBody(),
    );
  }
}
