// lib/core/repositories/location_repository_ext.dart
//
// This extension adds the API your UI expects WITHOUT changing
// your existing LocationRepository implementation.
//
// It assumes your existing repository exposes a `data` map like:
//   Map<String, List<String>> get data
//
// If your repo already has regions/cities methods, this is still harmless.

import 'location_repository.dart';

extension LocationRepositoryX on LocationRepository {
  List<String> get regions {
    // If your repo already has a regions getter, prefer that.
    try {
      // ignore: avoid_dynamic_calls
      final dynamic any = this;
      if (any.regions is List<String>) {
        return (any.regions as List<String>)..sort();
      }
    } catch (_) {}
    // Fallback to .data
    // ignore: avoid_dynamic_calls
    final Map<String, List<String>> map =
        (this as dynamic).data as Map<String, List<String>>;
    final r = map.keys.toList()..sort();
    return r;
  }

  List<String> citiesFor(String region) {
    try {
      // ignore: avoid_dynamic_calls
      final dynamic any = this;
      if (any.citiesFor is Function) {
        return (any.citiesFor(region) as List)
            .map((e) => e.toString())
            .toList();
      }
    } catch (_) {}
    // Fallback to .data
    // ignore: avoid_dynamic_calls
    final Map<String, List<String>> map =
        (this as dynamic).data as Map<String, List<String>>;
    return List<String>.from(map[region] ?? const <String>[]);
  }
}
