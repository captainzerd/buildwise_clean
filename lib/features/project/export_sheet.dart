import '../../core/config/service_locator.dart';
// lib/features/project/export_sheet.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/auth_service.dart';
import '../../core/services/csv_service.dart';
import '../../core/services/export_service.dart';
import '../../core/services/payment_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/services/project_service.dart';

class ExportSheet extends StatefulWidget {
  const ExportSheet({
    super.key,
    required this.projectId,
    required this.ownerUid,
  });

  final String projectId;
  final String ownerUid;

  @override
  State<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<ExportSheet> {
  _ExportOption? _busy;

  ExportService _buildService(BuildContext context) => ExportService(
        projectService: sl<ProjectService>(),
        paymentService: sl<PaymentService>(),
        csvService: CsvService(),
        pdfService: PdfService(),
      );

  Future<void> _run(_ExportOption option, Future<void> Function() action) async {
    setState(() => _busy = option);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Export failed: $e'), duration: const Duration(seconds: 10)));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final ownerName = auth.currentUser?.displayName ?? '';
    final svc = _buildService(context);
    final isOwner = auth.currentUser?.uid == widget.ownerUid;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Export',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          _ExportTile(
            icon: Icons.table_chart_outlined,
            title: 'Cost Entries (CSV)',
            subtitle: 'All cost entries as a spreadsheet',
            loading: _busy == _ExportOption.costCsv,
            onTap: () => _run(
              _ExportOption.costCsv,
              () => svc.exportCostEntriesCsv(widget.projectId, ''),
            ),
          ),
          _ExportTile(
            icon: Icons.payments_outlined,
            title: 'Payments (CSV)',
            subtitle: 'All payment records as a spreadsheet',
            loading: _busy == _ExportOption.paymentCsv,
            onTap: () => _run(
              _ExportOption.paymentCsv,
              () => svc.exportPaymentsCsv(widget.projectId, ''),
            ),
          ),
          _ExportTile(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Full Project Report (PDF)',
            subtitle: 'Phases, costs, payments in one PDF',
            loading: _busy == _ExportOption.projectPdf,
            onTap: () => _run(
              _ExportOption.projectPdf,
              () => svc.exportProjectPdf(widget.projectId),
            ),
          ),
          if (isOwner)
            _ExportTile(
              icon: Icons.folder_zip_outlined,
              title: 'Portfolio Summary (PDF)',
              subtitle: 'All your projects in one PDF',
              loading: _busy == _ExportOption.portfolioPdf,
              onTap: () => _run(
                _ExportOption.portfolioPdf,
                () => svc.exportPortfolioPdf(
                  widget.ownerUid,
                  ownerName: ownerName,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ExportOption { costCsv, paymentCsv, projectPdf, portfolioPdf }

class _ExportTile extends StatelessWidget {
  const _ExportTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: loading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, color: Theme.of(context).colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: loading ? null : onTap,
    );
  }
}
