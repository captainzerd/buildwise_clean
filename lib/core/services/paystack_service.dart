// lib/core/services/paystack_service.dart
//
// Thin wrapper around the Paystack Payment Initialization API.
// Docs: https://paystack.com/docs/api/transaction/#initialize
//
// NOTE: The PUBLIC key is safe to bundle in the app.
// The SECRET key must NEVER leave the server — initialization is done
// through a Firebase Cloud Function or your own backend.
//
// This service calls your Firebase Callable Function `initPaystackTransaction`
// which returns {authorizationUrl, reference} from Paystack.

import 'package:cloud_functions/cloud_functions.dart';

class PaystackService {
  PaystackService({FirebaseFunctions? functions})
      : _fn = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _fn;

  /// Calls the `initPaystackTransaction` Cloud Function and returns the
  /// Paystack authorization URL to load in a WebView.
  ///
  /// [amountGhs] — payment amount in GHS (converted to pesewas × 100).
  /// [email] — payer's email (required by Paystack).
  /// [reference] — unique reference for this payment (use a UUID).
  /// [metadata] — optional flat map of extra data stored against the payment.
  Future<PaystackInitResult> initTransaction({
    required double amountGhs,
    required String email,
    required String reference,
    Map<String, dynamic> metadata = const {},
  }) async {
    final callable = _fn.httpsCallable('initPaystackTransaction');
    final result = await callable.call<Map>({
      'amountPesewas': (amountGhs * 100).round(),
      'email': email,
      'reference': reference,
      'metadata': metadata,
    });
    final data = Map<String, dynamic>.from(result.data);
    return PaystackInitResult(
      authorizationUrl: data['authorizationUrl'] as String,
      reference: data['reference'] as String,
    );
  }
}

class PaystackInitResult {
  const PaystackInitResult({
    required this.authorizationUrl,
    required this.reference,
  });

  final String authorizationUrl;
  final String reference;
}
