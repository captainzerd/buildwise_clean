import 'package:buildwise_domain/buildwise_domain.dart';

class EstimateRepositoryMemory implements EstimateRepository {
  final _store = <String, Estimate>{};

  @override
  Future<Estimate> save(Estimate estimate) async {
    _store[estimate.id] = estimate;
    return estimate;
  }

  @override
  Future<Estimate?> getById(String id) async => _store[id];
}
