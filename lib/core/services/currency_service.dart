import 'package:flutter/foundation.dart';

/// Display currency only. Internally your model uses GHS.
/// Add or tweak rates in the controller or service that consumes this.
enum Currency { ghs, usd, gbp }

class CurrencyService with ChangeNotifier {
  /// Current display currency (public field instead of trivial getter/setter).
  Currency currency = Currency.ghs;

  /// Example rates; your controller can override/extend as needed.
  /// Value = (symbol, rateFromGhs)
  Map<Currency, (String symbol, double rate)> get rates => const {
        Currency.ghs: ('GH₵', 1.0),
        Currency.usd: ('\$', 0.075),
        Currency.gbp: ('£', 0.059),
      };

  void setCurrency(Currency c) {
    if (currency == c) return;
    currency = c;
    notifyListeners();
  }
}
