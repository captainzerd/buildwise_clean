import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart';

/// Loads Ghana regions (+ optional cities) from assets with a safe fallback.
/// Notifies listeners when data changes so UI can rebuild.
class LocationRepository extends ChangeNotifier {
  static const String defaultAssetPath = 'assets/data/ghana_locations.json';

  // region -> cities
  Map<String, List<String>> _data = {};

  bool _loaded = false;
  bool get isLoaded => _loaded;

  List<String> get regions {
    final keys = _data.keys.toList();
    keys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return keys;
  }

  List<String> citiesFor(String? region) {
    if (region == null) return const [];
    final list = _data[region] ?? const [];
    // keep order stable but trimmed
    return list.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  }

  /// Call once at app start. Safe to call multiple times; it will just refresh.
  Future<void> loadFromAssets({String path = defaultAssetPath}) async {
    try {
      final jsonStr = await rootBundle.loadString(path);
      final dynamic raw = json.decode(jsonStr);

      _data = _normalize(raw);
      if (_data.isEmpty) {
        _useFallback();
      }
    } catch (_) {
      _useFallback();
    }
    _loaded = true;
    notifyListeners();
  }

  /// Accepts multiple shapes:
  /// 1) {"regions": {"Greater Accra":["Accra","Tema"], ...}}
  /// 2) {"Greater Accra":["Accra","Tema"], ...}
  /// 3) [{"region":"Greater Accra","cities":["Accra","Tema"]}, ...]
  Map<String, List<String>> _normalize(dynamic raw) {
    final Map<String, List<String>> out = {};

    if (raw is Map<String, dynamic>) {
      // Case 1: wrapped in "regions"
      if (raw['regions'] is Map<String, dynamic>) {
        final m = raw['regions'] as Map<String, dynamic>;
        m.forEach((k, v) {
          out[_clean(k)] = _asStringList(v);
        });
        return out;
      }
      // Case 2: direct map region->cities
      bool looksLikeDirect = raw.values.every((v) => v is List);
      if (looksLikeDirect) {
        raw.forEach((k, v) {
          out[_clean(k)] = _asStringList(v);
        });
        return out;
      }
    }

    // Case 3: list of objects {region, cities}
    if (raw is List) {
      for (final e in raw) {
        if (e is Map) {
          final region = _clean(e['region'] ?? '');
          if (region.isEmpty) continue;
          out[region] = _asStringList(e['cities']);
        }
      }
      return out;
    }

    return out;
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) {
      return v
          .map((e) => e?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
    }
    return const [];
  }

  String _clean(String s) => s.trim();

  void _useFallback() {
    // Minimal, safe fallback so dropdowns still work.
    // You can expand/update this list anytime.
    _data = <String, List<String>>{
      'Greater Accra': ['Accra', 'Tema', 'Madina'],
      'Ashanti': ['Kumasi', 'Obuasi', 'Tafo'],
      'Western': ['Sekondi-Takoradi', 'Tarkwa'],
      'Northern': ['Tamale', 'Yendi'],
      'Central': ['Cape Coast', 'Mankessim'],
      'Eastern': ['Koforidua', 'Nkawkaw'],
      'Volta': ['Ho', 'Keta'],
      'Upper East': ['Bolgatanga', 'Navrongo'],
      'Upper West': ['Wa'],
      'Bono': ['Sunyani', 'Berekum'],
      'Ahafo': ['Goaso'],
      'Bono East': ['Techiman'],
      'Oti': ['Dambai'],
      'Savannah': ['Damongo'],
      'North East': ['Nalerigu'],
      'Western North': ['Sefwi Wiawso'],
    };
  }
}
