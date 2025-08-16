import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loads Ghana regions/cities from the app bundle.
/// Returns a map: { "RegionName": ["City1","City2",...] }
class LocationRepository {
  // Keep a single asset path here so it’s easy to change later.
  static const String _assetPath = 'assets/data/ghana_locations.json';

  Future<Map<String, List<String>>> load() async {
    if (kDebugMode) {
      // (Fix: enclose single-line if body in a block to satisfy the lint)
      debugPrint('Attempting to load location data from: $_assetPath');
    }

    final raw = await rootBundle.loadString(_assetPath);
    if (kDebugMode) {
      debugPrint('Loaded asset contents (first 100 chars): '
          '${raw.substring(0, raw.length > 100 ? 100 : raw.length)}');
    }

    final decoded = json.decode(raw) as Map<String, dynamic>;
    final regions = decoded['regions'] as List<dynamic>? ?? const [];

    final Map<String, List<String>> result = {};
    for (final r in regions) {
      final regionName = (r['name'] ?? '').toString();
      final cities = (r['cities'] as List<dynamic>? ?? const [])
          .map((c) => c.toString())
          .toList();
      cities.sort();
      if (regionName.isNotEmpty) {
        result[regionName] = cities;
      }
    }

    return result;
  }
}
