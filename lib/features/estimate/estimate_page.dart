// lib/features/estimate/estimate_page.dart
//
// Page shell that wires the controller with all required services.

import 'package:flutter/material.dart';

import '../../core/repositories/location_repository.dart';
import '../../core/services/estimate_service.dart';
import '../../core/services/expense_service.dart';
import '../../core/services/pdf_service.dart';
import '../../core/data/ghana_catalog_adapter.dart';

import 'state/estimate_controller.dart';
import 'widgets/estimate_body.dart';

class EstimatePage extends StatefulWidget {
  const EstimatePage({super.key});

  @override
  State<EstimatePage> createState() => _EstimatePageState();
}

class _EstimatePageState extends State<EstimatePage> {
  late final EstimateController ctrl;

  @override
  void initState() {
    super.initState();
    // Wire the adapter into the service, then into the controller.
    final estimateSvc = EstimateService(catalog: const GhanaCatalogAdapter());
    ctrl = EstimateController(
      estimateService: estimateSvc,
      expenseService: ExpenseService(),
      locationRepo: LocationRepository(),
      pdf: PdfService(),
    )..init();

    // If you previously set `ctrl.currency = ...`, replace with:
    // ctrl.setCurrency(Currency.ghs); // optional default
  }

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        return Scaffold(
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: EstimateBody(ctrl: ctrl),
            ),
          ),
        );
      },
    );
  }
}
