// lib/features/estimate/state/estimate_controller_legacy.dart
import 'package:flutter/foundation.dart';
import '../../../core/services/pdf_service.dart';
import '../../../core/services/storage/storage_service.dart';
import 'estimate_controller.dart';

/// Back-compat surface used by older widgets.
/// Wraps the modern EstimateController and services.
class EstimateControllerLegacy {
  final EstimateController ctrl;
  final PdfService pdf;
  final StorageService storage;

  EstimateControllerLegacy(
    this.ctrl, {
    PdfService? pdf,
    StorageService? storage,
  })  : pdf = pdf ?? PdfService(),
        storage = storage ?? StorageService();

  /// Build and save a PDF using the new PdfService API.
  Future<String> exportSummary() async {
    // Make sure results exist
    if (!ctrl.hasResult) {
      ctrl.generate();
    }
    final bytes = await pdf.buildEstimatePdf(
      projectName: ctrl.projectNameCtrl.text,
      region: ctrl.region,
      city: ctrl.city,
      currencyPretty: ctrl.currencySymbol,
      unitPretty: ctrl.unit.name,
      totalPlanned: ctrl.totalPlanned,
      phaseBreakdown: ctrl.phaseBreakdown,
      baseCost: ctrl.baseCost,
      extraSubstructure: ctrl.extraSubstructure,
      stairsCost: ctrl.stairsCost,
    );
    final suggested = (ctrl.projectNameCtrl.text.isEmpty
            ? 'estimate'
            : ctrl.projectNameCtrl.text) +
        '.pdf';
    return pdf.savePdfBytes(bytes, suggestedFileName: suggested);
  }

  /// Save current estimate JSON to storage.
  Future<String?> saveEstimateJson() async {
    final name = ctrl.projectNameCtrl.text.isEmpty
        ? 'estimate'
        : ctrl.projectNameCtrl.text;
    return storage.saveEstimateJson(ctrl.toJson(), fileName: name);
  }
}
