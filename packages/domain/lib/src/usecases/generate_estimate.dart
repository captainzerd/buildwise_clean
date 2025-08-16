// lib/src/usecases/generate_estimate.dart
import '../entities/estimate.dart';

class GenerateEstimateInput {
  final String projectName;
  final Map<String, double> phaseBudget;

  const GenerateEstimateInput({
    required this.projectName,
    required this.phaseBudget,
  });
}

class GenerateEstimate {
  Estimate call(GenerateEstimateInput input) {
    return Estimate(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      projectName: input.projectName,
      phaseBudget: input.phaseBudget,
    );
  }
}
