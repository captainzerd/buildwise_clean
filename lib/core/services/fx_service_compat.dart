// Thin adapter — keeps older call shapes compiling without changes.
import '../models/currency.dart' show CurrencyInfo;
import 'fx_service.dart';

class FxServiceCompat {
  FxServiceCompat(this.fx);
  final FxService fx;

  double convert({required double amountGhs, required CurrencyInfo to}) =>
      fx.convertFromGhs(amountGhs: amountGhs, to: to.code);

  double convertFromGhs({required double amountGhs, required String to}) =>
      fx.convertFromGhs(amountGhs: amountGhs, to: to);
}
