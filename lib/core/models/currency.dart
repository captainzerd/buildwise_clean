import '../services/fx_service.dart';

/// Supported display currencies for the app.
enum AppCurrency { ghs, usd, eur, gbp }

extension AppCurrencyX on AppCurrency {
  /// ISO-ish code used across UI and storage.
  String get code => switch (this) {
        AppCurrency.ghs => 'GHS',
        AppCurrency.usd => 'USD',
        AppCurrency.eur => 'EUR',
        AppCurrency.gbp => 'GBP',
      };

  /// Symbol used for formatting.
  String get symbol => switch (this) {
        AppCurrency.ghs => '₵',
        AppCurrency.usd => r'$',
        AppCurrency.eur => '€',
        AppCurrency.gbp => '£',
      };

  /// “£ GBP”, “$ USD”, etc.
  String get pretty => '$symbol $code';

  /// Format a number in this currency with thousands separators and fixed decimals.
  /// (No dependency on `intl`.)
  String format(num amount, {int fractionDigits = 2}) {
    final sign = amount.isNegative ? '-' : '';
    final v = amount.abs().toDouble();
    final fixed = v.toStringAsFixed(fractionDigits);
    final parts = fixed.split('.');
    final intPart = parts[0];
    final decPart = (fractionDigits > 0 && parts.length > 1) ? parts[1] : '';

    // Insert thousands separators into the integer part.
    final rev = intPart.split('').reversed.toList();
    final buf = StringBuffer();
    for (int i = 0; i < rev.length; i++) {
      if (i > 0 && i % 3 == 0) buf.write(',');
      buf.write(rev[i]);
    }
    final intFormatted = buf.toString().split('').reversed.join();

    final body = fractionDigits > 0 ? '$intFormatted.$decPart' : intFormatted;
    return '$symbol $sign$body';
  }

  /// Convert a GHS amount into this currency using [fx].
  /// If this==GHS, returns the input.
  double fromGhs(double ghsAmount, FxService fx) {
    if (this == AppCurrency.ghs) return ghsAmount;
    // NOTE: FxService.ghsTo takes (double amount, String toCode)
    return fx.ghsTo(ghsAmount, code);
  }

  /// Parse from code; defaults to GHS on unknown input.
  static AppCurrency fromCode(String? c) {
    switch ((c ?? '').toUpperCase()) {
      case 'USD':
        return AppCurrency.usd;
      case 'EUR':
        return AppCurrency.eur;
      case 'GBP':
        return AppCurrency.gbp;
      case 'GHS':
      default:
        return AppCurrency.ghs;
    }
  }
}
