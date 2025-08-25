// lib/core/services/rate_provider.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class RateProvider {
  final http.Client _client;
  RateProvider({http.Client? client}) : _client = client ?? http.Client();

  /// Returns GHS -> { 'USD': x, 'GBP': y }
  Future<Map<String, double>> ghsToRates() async {
    try {
      // Frankfurter API is free and simple
      final uri =
          Uri.parse('https://api.frankfurter.app/latest?from=GHS&to=USD,GBP');
      final res = await _client.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final rates = Map<String, double>.from(
          (json['rates'] as Map)
              .map((k, v) => MapEntry(k.toString(), (v as num).toDouble())),
        );
        // Ensure the keys exist
        return {'USD': rates['USD'] ?? 0.075, 'GBP': rates['GBP'] ?? 0.059};
      }
    } catch (_) {}
    // Fallback (last known / placeholder)
    return {'USD': 0.075, 'GBP': 0.059};
  }
}
