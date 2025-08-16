import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class LocationRepository {
  Map<String, List<String>>? _cache;

  Future<Map<String, List<String>>> _load() async {
    if (_cache != null) return _cache!;
    final jsonStr = await rootBundle.loadString(
      'assets/data/ghana_locations.json',
    );
    final Map<String, dynamic> raw = json.decode(jsonStr);
    _cache = raw.map<String, List<String>>(
      (k, v) => MapEntry(k, List<String>.from(v as List)),
    );
    return _cache!;
  }

  Future<List<String>> regions() async =>
      (await _load()).keys.toList(growable: false);

  Future<List<String>> cities(String region) async =>
      List<String>.from((await _load())[region] ?? const <String>[]);
}
