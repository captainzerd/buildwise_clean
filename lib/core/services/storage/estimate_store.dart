// lib/core/services/storage/estimate_store.dart
//
// Lightweight in-memory store. Keeps the same API the rest of the app
// already expects.

import '../../models/estimate.dart'; // <-- fixed import depth

class EstimateStore {
  static final EstimateStore _instance = EstimateStore._();
  EstimateStore._();
  factory EstimateStore() => _instance;

  final List<Estimate> _items = [];

  Future<List<Estimate>> list() async => List<Estimate>.from(_items);

  Future<void> save(Estimate est) async {
    final idx = _items.indexWhere((e) => e.projectId == est.projectId);
    if (idx >= 0) {
      _items[idx] = est;
    } else {
      _items.add(est);
    }
  }

  Future<void> delete(String id) async {
    _items.removeWhere((e) => e.projectId == id);
  }

  Future<void> clear() async {
    _items.clear();
  }
}
