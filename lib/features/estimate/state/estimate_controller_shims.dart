/*
  Lightweight shims that adapt whatever the current EstimateController exposes
  to what the UI expects, without removing any functionality.
*/
import 'package:buildwise_clean/features/estimate/state/estimate_controller.dart';

extension EstimateControllerShims on EstimateController {
  Map<String, num> get phasePlanned {
    final self = this as dynamic;
    try {
      final v = self.phasePlanned;
      if (v is Map<String, num>) return v;
    } catch (_) {}
    try {
      final v = self.estimate?.phasePlanned;
      if (v is Map<String, num>) return v;
    } catch (_) {}
    try {
      final v = self.results?.phasePlanned ?? self.summary?.phasePlanned;
      if (v is Map<String, num>) return v;
    } catch (_) {}
    return const <String, num>{};
  }

  void primeResults({
    Map<String, num>? phaseBreakdown,
    double? baseCostGhs,
    double? extraSubstructureGhs,
    double? stairsCostGhs,
    double? totalPlannedGhs,
  }) {
    final self = this as dynamic;

    try {
      if (self.primeResults is Function) {
        self.primeResults(
          phaseBreakdown: phaseBreakdown,
          baseCostGhs: baseCostGhs,
          extraSubstructureGhs: extraSubstructureGhs,
          stairsCostGhs: stairsCostGhs,
          totalPlannedGhs: totalPlannedGhs,
        );
        return;
      }
    } catch (_) {}

    try {
      if (self.updatePhaseBreakdown is Function && phaseBreakdown != null) {
        self.updatePhaseBreakdown(phaseBreakdown);
      }
    } catch (_) {}

    try {
      if (self.setBaseCosts is Function && baseCostGhs != null) {
        self.setBaseCosts(baseCostGhs);
      }
    } catch (_) {}

    try {
      if (self.setExtraSubstructure is Function &&
          extraSubstructureGhs != null) {
        self.setExtraSubstructure(extraSubstructureGhs);
      }
    } catch (_) {}

    try {
      if (self.setStairsCost is Function && stairsCostGhs != null) {
        self.setStairsCost(stairsCostGhs);
      }
    } catch (_) {}

    try {
      if (self.setTotalPlanned is Function && totalPlannedGhs != null) {
        self.setTotalPlanned(totalPlannedGhs);
      }
    } catch (_) {}
  }
}
