class CurrencyInfo {
  final String code;
  final String symbol;
  final String name;

  const CurrencyInfo(this.code, this.symbol, {this.name = ''});

  static const ghs = CurrencyInfo('GHS', 'GH₵', name: 'Ghana Cedi');
  static const usd = CurrencyInfo('USD', '\$', name: 'US Dollar');
  static const gbp = CurrencyInfo('GBP', '£', name: 'British Pound');
  static const eur = CurrencyInfo('EUR', '€', name: 'Euro');
  static const cad = CurrencyInfo('CAD', 'CA\$', name: 'Canadian Dollar');
  static const aud = CurrencyInfo('AUD', 'AU\$', name: 'Australian Dollar');
  static const ngn = CurrencyInfo('NGN', '₦', name: 'Nigerian Naira');

  static const values = [ghs, usd, gbp, eur, cad, aud, ngn];

  static CurrencyInfo fromCode(String code) {
    final up = code.toUpperCase();
    for (final c in values) {
      if (c.code == up) return c;
    }
    return CurrencyInfo(up, up, name: up);
  }

  @override
  bool operator ==(Object other) =>
      other is CurrencyInfo && other.code == code;

  @override
  int get hashCode => code.hashCode;
}
