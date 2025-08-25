// Simple currency model restricted to USD/GBP/EUR/GHS.
// No intl dependency; includes a lightweight thousands formatter.

enum AppCurrency { usd, gbp, eur, ghs }

extension CurrencyX on AppCurrency {
  String get code {
    switch (this) {
      case AppCurrency.usd:
        return 'USD';
      case AppCurrency.gbp:
        return 'GBP';
      case AppCurrency.eur:
        return 'EUR';
      case AppCurrency.ghs:
        return 'GHS';
    }
  }

  String get symbol {
    switch (this) {
      case AppCurrency.usd:
        return '\$';
      case AppCurrency.gbp:
        return '£';
      case AppCurrency.eur:
        return '€';
      case AppCurrency.ghs:
        return '₵';
    }
  }

  /// Format with thousands separators and 2 decimals by default.
  String format(num amount, {int decimals = 2}) {
    final fixed = amount.toStringAsFixed(decimals);
    final parts = fixed.split('.');
    final whole = parts[0];
    final dec = parts.length > 1 ? parts[1] : '';
    final re = RegExp(r'(\d+)(\d{3})');
    String out = whole;
    while (re.hasMatch(out)) {
      out = out.replaceAllMapped(re, (m) => '${m[1]},${m[2]}');
    }
    return dec.isEmpty ? '$symbol$out' : '$symbol$out.$dec';
  }

  static const supported = [
    AppCurrency.usd,
    AppCurrency.gbp,
    AppCurrency.eur,
    AppCurrency.ghs,
  ];
}
