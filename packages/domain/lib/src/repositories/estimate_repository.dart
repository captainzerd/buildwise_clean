import '../entities/estimate.dart';

abstract class EstimateRepository {
  Future<Estimate> save(Estimate estimate);
  Future<Estimate?> getById(String id);
}
