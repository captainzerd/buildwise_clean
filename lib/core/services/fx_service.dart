import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/currency.dart';

/// Live GHS-based FX service.
///
/// Rate loading priority:
///   1. SharedPreferences cache (instant, works offline).
///   2. Background fetch from open.er-api.com if cache is older than 4 hours.
///
/// Call [warmUp] once at app startup. Widgets that display converted
/// amounts should `context.watch` this service so they rebuild when
/// fresh rates arrive.
class FxService extends ChangeNotifier {
  static const _cacheKey = 'fx_rates_v1';
  static const _staleDuration = Duration(hours: 4); // refresh threshold
  static const _apiUrl =
      'https://open.er-api.com/v6/latest/GHS';

  // Fallback rates (approximate, used before any fetch succeeds).
  static const _defaultRates = <String, double>{
    'USD': 0.075,
    'GBP': 0.058,
    'EUR': 0.069,
    'CAD': 0.103,
    'AUD': 0.116,
    'NGN': 123.5,
  };

  Map<String, double> _rates = Map.of(_defaultRates);
  DateTime? _lastUpdated;
  bool _isLoading = false;
  String? _error;

  Map<String, double> get rates => Map.unmodifiable(_rates);
  DateTime? get lastUpdated => _lastUpdated;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get isStale =>
      _lastUpdated == null ||
      DateTime.now().difference(_lastUpdated!) > _staleDuration;

  // ── Startup ──

  /// Load cached rates and kick off a background refresh if stale.
  Future<void> warmUp() async {
    await _loadFromCache();
    if (isStale) {
      // Don't await — fetch in background so the app boots instantly.
      unawaited(_fetchAndCache());
    }
  }

  /// Force a fresh fetch regardless of cache freshness.
  Future<void> refresh() => _fetchAndCache();

  // ── Conversion ──

  /// Convert [amountGhs] to [to] currency code. Returns GHS amount unchanged
  /// if the rate is unavailable.
  double convertFromGhs({required double amountGhs, required String to}) {
    if (to == 'GHS') return amountGhs;
    final rate = _rates[to];
    if (rate == null || rate <= 0) return amountGhs;
    return amountGhs * rate;
  }

  /// Rate for [currencyCode] expressed as "1 GHS = X {code}".
  double rateFor(String currencyCode) => _rates[currencyCode] ?? 0;

  // ── Cache ──

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final timestamp = DateTime.tryParse(data['timestamp'] as String? ?? '');
      final ratesRaw = data['rates'] as Map<String, dynamic>?;

      if (ratesRaw != null) {
        _rates = {
          ..._defaultRates,
          ...ratesRaw.map((k, v) => MapEntry(k, (v as num).toDouble())),
        };
        _lastUpdated = timestamp;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('FxService: cache read error — $e');
    }
  }

  Future<void> _saveToCache(Map<String, double> rates) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _cacheKey,
        jsonEncode({
          'timestamp': DateTime.now().toIso8601String(),
          'rates': rates,
        }),
      );
    } catch (e) {
      debugPrint('FxService: cache write error — $e');
    }
  }

  // ── API fetch ──

  Future<void> _fetchAndCache() async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http
          .get(Uri.parse(_apiUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }

      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw Exception('Unexpected API response format');
      }

      if (body['result'] != 'success') {
        throw Exception('API returned: ${body['result']}');
      }

      final rawRates = body['rates'] as Map<String, dynamic>?;
      if (rawRates == null) {
        throw Exception('Missing rates in API response');
      }
      final fetched = rawRates.map(
        (k, v) => MapEntry(k, (v as num).toDouble()),
      );

      // Keep only the currencies we care about.
      final filtered = <String, double>{};
      for (final c in CurrencyInfo.values) {
        if (c.code == 'GHS') continue;
        final rate = fetched[c.code];
        if (rate != null) filtered[c.code] = rate;
      }

      _rates = {..._defaultRates, ...filtered};
      _lastUpdated = DateTime.now();
      _error = null;

      await _saveToCache(_rates);
    } catch (e) {
      _error = 'Could not refresh exchange rates. Showing last known rates.';
      debugPrint('FxService: fetch error — $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Dart ≥ 3 exposes unawaited() in dart:async but older toolchains need this:
void unawaited(Future<void> future) {
  future.ignore();
}
