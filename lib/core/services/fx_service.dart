// lib/core/services/fx_service.dart
//
// Deterministic FX with live-refresh hook (no HTTP needed for compile).
// Base currency is GHS.
// - rateTo(code): units of [code] per 1 GHS
// - ghsTo(amountGhs, code): convert GHS -> target
// - convertFromGhs(...): alias kept for older call-sites

import 'dart:async';

class FxService {
  FxService({
    Map<String, double>? initialRatesTo,
    DateTime? lastUpdated,
  })  : _ratesTo = {
          'GHS': 1.0,
          'USD': 0.073, // placeholder; wire live later
          'EUR': 0.067,
          'GBP': 0.057,
          'NGN': 110.0,
          'ZAR': 1.34,
          ...?initialRatesTo,
        },
        _lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, double> _ratesTo;
  DateTime _lastUpdated;

  DateTime get lastUpdated => _lastUpdated;

  double rateTo(String code) => _ratesTo[code.toUpperCase()] ?? 1.0;

  double ghsTo(num amountGhs, String code) =>
      amountGhs.toDouble() * rateTo(code);

  double convertFromGhs(num amountGhs, String code) => ghsTo(amountGhs, code);

  void setRates(Map<String, double> ratesTo) {
    _ratesTo = {
      ..._ratesTo,
      ...ratesTo.map((k, v) => MapEntry(k.toUpperCase(), v.toDouble())),
    };
    _lastUpdated = DateTime.now();
  }

  Future<void> refreshIfStale(
      {Duration maxAge = const Duration(hours: 12)}) async {
    final now = DateTime.now();
    final age = now.difference(_lastUpdated);
    if (age < maxAge) return;
    // TODO: fetch live rates; then call setRates(...)
    _lastUpdated = now;
  }
}
