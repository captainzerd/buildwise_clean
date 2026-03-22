/// Build-time environment. Pass via --dart-define=ENV=dev|staging|prod
/// Defaults to 'dev' when not set.
const String kEnv = String.fromEnvironment('ENV', defaultValue: 'dev');

const bool kIsProduction = kEnv == 'prod';
const bool kIsStaging = kEnv == 'staging';
const bool kIsDev = kEnv == 'dev';

/// Legacy: whether to use cloud services (always true now; kept for compat).
const bool kUseCloud = true;

/// Backwards-compat alias.
bool get canUseCloud => kUseCloud;

// ── Paystack public keys ─────────────────────────────────────────────────────
// The PUBLIC key is safe to bundle in the app.
// The SECRET key lives server-side in the `initPaystackTransaction` Cloud
// Function and is injected at deploy time via Firebase Secret Manager:
//   firebase functions:secrets:set PAYSTACK_SECRET_KEY
//
// To switch to live keys, build with --dart-define=ENV=prod and set the live
// secret key in Firebase Secret Manager.

const String kPaystackPublicKey = kIsProduction
    ? String.fromEnvironment(
        'PAYSTACK_PUBLIC_KEY',
        defaultValue: 'pk_live_REPLACE_WITH_LIVE_PUBLIC_KEY',
      )
    : String.fromEnvironment(
        'PAYSTACK_PUBLIC_KEY',
        defaultValue: 'pk_test_REPLACE_WITH_TEST_PUBLIC_KEY',
      );

// ── Stripe publishable keys ───────────────────────────────────────────────────
// PUBLIC key only — safe to bundle.
// Set SECRET key in Firebase Secret Manager:
//   firebase functions:secrets:set STRIPE_SECRET_KEY
//   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
const String kStripePublishableKey = kIsProduction
    ? String.fromEnvironment(
        'STRIPE_PUBLISHABLE_KEY',
        defaultValue: 'pk_live_REPLACE_WITH_LIVE_PUBLISHABLE_KEY',
      )
    : String.fromEnvironment(
        'STRIPE_PUBLISHABLE_KEY',
        defaultValue: 'pk_test_REPLACE_WITH_TEST_PUBLISHABLE_KEY',
      );

class AppConfig {
  AppConfig._();
  static final AppConfig instance = AppConfig._();
  bool get useCloud => kUseCloud;
  String get env => kEnv;
  bool get isProduction => kIsProduction;

  /// Paystack public key for the current environment.
  String get paystackPublicKey => kPaystackPublicKey;

  /// Stripe publishable key for the current environment.
  String get stripePublishableKey => kStripePublishableKey;
}
