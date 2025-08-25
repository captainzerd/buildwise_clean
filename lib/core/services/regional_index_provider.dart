// lib/core/services/regional_index_provider.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class RegionalIndexProvider {
  RegionalIndexProvider();

  List<String> _regions = const [];
  bool _loaded = false;

  bool get isReady => _loaded;
  List<String> get regions => _regions;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final raw = await rootBundle.loadString(
        'assets/data/ghana_locations.json',
      );
      final json = jsonDecode(raw);
      final list = (json['regions'] as List?) ?? const [];
      _regions = [
        for (final r in list)
          if (r is Map && r['name'] is String) (r['name'] as String),
      ];
      if (_regions.isEmpty) {
        _regions = const [
          'Greater Accra',
          'Ashanti',
          'Western',
          'Eastern',
          'Central',
          'Northern',
          'Volta',
          'Upper East',
          'Upper West',
          'Bono',
          'Ahafo',
          'Savannah',
          'North East',
          'Oti',
          'Bono East',
          'Western North',
        ];
      }
      _loaded = true;
    } catch (_) {
      _regions = const [
        'Greater Accra',
        'Ashanti',
        'Western',
        'Eastern',
        'Central',
        'Northern',
        'Volta',
        'Upper East',
        'Upper West',
        'Bono',
        'Ahafo',
        'Savannah',
        'North East',
        'Oti',
        'Bono East',
        'Western North',
      ];
      _loaded = true;
    }
  }

  Map<String, double> indexFor(String regionName) {
    return const {
      'ci': 1.0,
      'material': 1.0,
      'labour': 1.0,
      'transport': 1.0,
    };
  }
}
