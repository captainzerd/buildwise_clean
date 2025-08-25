// lib/features/estimate/state/estimate_controller_wiring.dart
import 'estimate_controller.dart';
import '../../../core/models/units.dart';

extension EstimateControllerWiring on EstimateController {
  // Legacy hook used in a few places
  void wire() {}

  // Legacy formatter alias
  String fmtMoney(num v) => formatMoney(v);

  // A couple of call sites still refer to phasePlanned by name
  Map<String, double> get phasePlanned => phaseBreakdown;

  // Some UI calls this after editing phases; treat as "recompute now"
  void primeResults() => generate();

  // Older code expected short unit codes; provide them here without touching Unit.
  String get unitAreaCode => unit.areaCode;
  String get unitLengthCode => unit.lengthCode;
}
