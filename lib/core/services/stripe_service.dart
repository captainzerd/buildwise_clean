// lib/core/services/stripe_service.dart
//
// Wraps flutter_stripe PaymentSheet for international card payments.
//
// Flow:
//   1. Call createStripePaymentIntent Cloud Function → receive clientSecret
//   2. Initialise Stripe PaymentSheet with the clientSecret
//   3. Present the sheet — user completes card / Apple Pay / Google Pay
//   4. On success, return the paymentIntentId for server-side activation
//
// Secret key never leaves the server. Only the publishable key is in the app.

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_stripe/flutter_stripe.dart';

class StripeService {
  StripeService({FirebaseFunctions? functions})
      : _fn = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _fn;

  /// Initialises and presents the Stripe PaymentSheet.
  ///
  /// [amountMinorUnits] is in minor units of [currency] (e.g. cents for USD/GBP,
  /// kobo for NGN, pesewas for GHS).
  ///
  /// Returns the `paymentIntentId` to pass to `activateStripeSubscription`.
  /// Throws [StripeException] if the user cancels, or any other error on failure.
  Future<String> presentPaymentSheet({
    required String email,
    required int amountMinorUnits,
    required String currency, // ISO 4217 lowercase, e.g. 'usd', 'gbp', 'ghs'
    required String tier,
    required String uid,
  }) async {
    // 1. Create PaymentIntent server-side
    final callable = _fn.httpsCallable('createStripePaymentIntent');
    final result = await callable.call<Map>({
      'amountCents': amountMinorUnits,
      'currency': currency,
      'email': email,
      'tier': tier,
      'uid': uid,
    });
    final data = Map<String, dynamic>.from(result.data as Map<Object?, Object?>);
    final clientSecret = data['clientSecret'] as String;
    // Extract PaymentIntent ID from the client secret (format: pi_xxx_secret_xxx)
    final paymentIntentId = clientSecret.split('_secret_').first;

    // 2. Initialise PaymentSheet
    await Stripe.instance.initPaymentSheet(
      paymentSheetParameters: SetupPaymentSheetParameters(
        paymentIntentClientSecret: clientSecret,
        merchantDisplayName: 'WyseBrix',
        googlePay: PaymentSheetGooglePay(
          merchantCountryCode: 'GH',
          currencyCode: currency.toUpperCase(),
          testEnv: kDebugMode,
        ),
        applePay: const PaymentSheetApplePay(
          merchantCountryCode: 'GH',
        ),
        style: ThemeMode.system,
        billingDetailsCollectionConfiguration:
            const BillingDetailsCollectionConfiguration(
          email: CollectionMode.automatic,
        ),
      ),
    );

    // 3. Present — throws StripeException on cancel/failure
    await Stripe.instance.presentPaymentSheet();

    return paymentIntentId;
  }
}
