// lib/core/services/export_service.dart
import 'dart:io';

import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import 'csv_service.dart';
import 'payment_service.dart';
import 'pdf_service.dart';
import 'project_service.dart';

class ExportService {
  ExportService({
    required ProjectService projectService,
    required PaymentService paymentService,
    required CsvService csvService,
    required PdfService pdfService,
  })  : _projectService = projectService,
        _paymentService = paymentService,
        _csvService = csvService,
        _pdfService = pdfService;

  final ProjectService _projectService;
  final PaymentService _paymentService;
  final CsvService _csvService;
  final PdfService _pdfService;

  // ── Per-project CSV ────────────────────────────────────────────────────────

  Future<void> exportCostEntriesCsv(String projectId, String projectTitle) async {
    final costs = await _projectService.costEntriesStream(projectId).first;
    final safeName = _safe(projectTitle);
    final file = await _csvService.exportCostEntries(
      costs,
      label: '${safeName}_cost_entries',
    );
    await _shareFile(file, 'cost_entries.csv');
  }

  Future<void> exportPaymentsCsv(String projectId, String projectTitle) async {
    final payments = await _paymentService.paymentsStream(projectId).first;
    final safeName = _safe(projectTitle);
    final file = await _csvService.exportPayments(
      payments,
      label: '${safeName}_payments',
    );
    await _shareFile(file, 'payments.csv');
  }

  // ── Per-project PDF ────────────────────────────────────────────────────────

  Future<void> exportProjectPdf(String projectId) async {
    final project = await _projectService.projectStream(projectId).first;
    if (project == null) return;

    final phases = await _projectService.phasesStream(projectId).first;
    final costs = await _projectService.costEntriesStream(projectId).first;
    final payments = await _paymentService.paymentsStream(projectId).first;

    final data = ProjectReportData(
      project: project,
      phases: phases,
      costs: costs,
      payments: payments,
    );

    final bytes = await _pdfService.generateProjectReport(data);
    final safeName = _safe(project.title);
    await Printing.sharePdf(bytes: bytes, filename: '${safeName}_report.pdf');
  }

  // ── Portfolio PDF ──────────────────────────────────────────────────────────

  Future<void> exportPortfolioPdf(
    String ownerUid, {
    String ownerName = '',
  }) async {
    final projects = await _projectService
        .projectsForOwner(ownerUid, limit: 100)
        .first;

    final dataList = <ProjectReportData>[];
    for (final project in projects) {
      final phases = await _projectService.phasesStream(project.id).first;
      final costs = await _projectService.costEntriesStream(project.id).first;
      final payments = await _paymentService.paymentsStream(project.id).first;
      dataList.add(
        ProjectReportData(
          project: project,
          phases: phases,
          costs: costs,
          payments: payments,
        ),
      );
    }

    final bytes = await _pdfService.generatePortfolioReport(
      dataList,
      ownerName: ownerName,
    );
    await Printing.sharePdf(bytes: bytes, filename: 'portfolio_report.pdf');
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _shareFile(File file, String shareFilename) async {
    await Share.shareXFiles(
      [XFile(file.path, name: shareFilename)],
    );
  }

  String _safe(String name) => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}
