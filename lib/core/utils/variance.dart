// lib/core/utils/variance.dart
import 'package:buildwise_domain/buildwise_domain.dart';

/// Planned amount for a phase from the estimate (0.0 if missing)
double plannedForPhase(Estimate e, String phase) => e.phaseBudget[phase] ?? 0.0;

/// Variance for a phase given the actual amount
double varianceForPhase(Estimate e, String phase, double actual) =>
    actual - plannedForPhase(e, phase);

/// Total variance given an actual total
double totalVariance(Estimate e, double actualTotal) => actualTotal - e.total;
