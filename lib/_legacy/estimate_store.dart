// lib/core/services/storage/storage_service.dart
//
// Minimal abstraction so controller can compile & save estimates.

import '../../models/estimate.dart';

abstract class StorageService {
  Future<void> saveEstimate(Estimate estimate);
  Future<List<Estimate>> loadEstimates();
  Future<void> deleteEstimate(Estimate estimate);
}
