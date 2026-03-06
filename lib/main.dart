import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/config/router.dart';
import 'core/config/service_locator.dart';
import 'core/services/auth_service.dart';
import 'core/services/boq_service.dart';
import 'core/services/builder_profile_service.dart';
import 'core/services/catalog_service.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/fx_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/pm_profile_service.dart';
import 'core/services/regional_index_provider.dart';
import 'core/services/sync_service.dart';
import 'core/services/variation_order_service.dart';
import 'core/services/vendor_service.dart';
import 'core/state/builder_project_state.dart';
import 'core/state/theme_mode_controller.dart';
import 'features/estimate/state/estimate_controller.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // App Check: debug provider in dev/debug; Play Integrity / DeviceCheck in prod.
  await FirebaseAppCheck.instance.activate(
    androidProvider:
        kIsProduction && !kDebugMode ? AndroidProvider.playIntegrity : AndroidProvider.debug,
    appleProvider:
        kIsProduction && !kDebugMode ? AppleProvider.deviceCheck : AppleProvider.debug,
  );

  // Crashlytics: only collect in production release builds.
  await FirebaseCrashlytics.instance
      .setCrashlyticsCollectionEnabled(kIsProduction && !kDebugMode);

  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Firestore offline persistence — must be set before any Firestore calls.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Stripe: set publishable key before any Stripe calls.
  Stripe.publishableKey = AppConfig.instance.stripePublishableKey;

  // Register all services in GetIt.
  await setupServiceLocator();

  // Async service initialisation.
  await sl<FxService>().warmUp();
  await sl<AuthService>().init();
  await sl<ThemeModeController>().init();

  try {
    await sl<NotificationService>().init();
  } catch (e) {
    // Non-fatal: FCM unavailable (e.g. iOS simulator). App runs without push notifications.
    debugPrint('NotificationService.init failed: $e');
  }
  sl<NotificationService>().listenToAuth(sl<AuthService>());

  await sl<BoqService>().init();
  sl<ConnectivityService>().start();

  runApp(const AppRoot());
}

class AppRoot extends StatelessWidget {
  const AppRoot({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(value: sl<AuthService>()),
        ChangeNotifierProvider<CatalogService>.value(value: sl<CatalogService>()),
        ChangeNotifierProvider<RegionalIndexProvider>.value(value: sl<RegionalIndexProvider>()),
        ChangeNotifierProvider<FxService>.value(value: sl<FxService>()),
        ChangeNotifierProvider<BuilderProfileService>.value(value: sl<BuilderProfileService>()),
        ChangeNotifierProvider<PmProfileService>.value(value: sl<PmProfileService>()),
        ChangeNotifierProvider<VendorService>.value(value: sl<VendorService>()),
        ChangeNotifierProvider<VariationOrderService>.value(value: sl<VariationOrderService>()),
        ChangeNotifierProvider<ThemeModeController>.value(value: sl<ThemeModeController>()),
        ChangeNotifierProvider<ConnectivityService>.value(value: sl<ConnectivityService>()),
        ChangeNotifierProvider<SyncService>.value(value: sl<SyncService>()),
        Provider<NotificationService>.value(value: sl<NotificationService>()),
        ChangeNotifierProvider<EstimateController>.value(value: sl<EstimateController>()),
        ChangeNotifierProvider<BuilderProjectState>.value(value: sl<BuilderProjectState>()),
      ],
      child: _PostFrameInit(
        onReady: (context) => context.read<EstimateController>().init(),
        child: const BuildWiseApp(),
      ),
    );
  }
}

class _PostFrameInit extends StatefulWidget {
  const _PostFrameInit({required this.onReady, required this.child});
  final void Function(BuildContext) onReady;
  final Widget child;

  @override
  State<_PostFrameInit> createState() => _PostFrameInitState();
}

class _PostFrameInitState extends State<_PostFrameInit> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady(context);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}


class BuildWiseApp extends StatelessWidget {
  const BuildWiseApp({super.key});

  static const _seed = Color(0xFF1565C0); // Blue 800 — professional, enterprise

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final cs = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);

    return ThemeData(
      colorScheme: cs,
      useMaterial3: true,
      fontFamily: 'NotoSans',

      // ── Scaffold ──
      scaffoldBackgroundColor:
          isDark ? cs.surface : const Color(0xFFF4F6FA),

      // ── AppBar ──
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: cs.surfaceTint,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
          letterSpacing: -0.3,
        ),
      ),

      // ── Cards ──
      cardTheme: CardThemeData(
        elevation: isDark ? 1 : 2,
        shadowColor: Colors.black.withValues(alpha: 0.07),
        surfaceTintColor: Colors.transparent,
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.zero,
      ),

      // ── Input fields ──
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? cs.surfaceContainerHighest.withValues(alpha: 0.4)
            : cs.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: cs.error, width: 2),
        ),
      ),

      // ── Buttons ──
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontFamily: 'NotoSans',
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),

      // ── Navigation bar ──
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        indicatorColor: cs.primaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.onPrimaryContainer, size: 24);
          }
          return IconThemeData(color: cs.onSurfaceVariant, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'NotoSans',
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            );
          }
          return TextStyle(
            fontFamily: 'NotoSans',
            fontSize: 12,
            color: cs.onSurfaceVariant,
          );
        }),
      ),

      // ── Dialogs ──
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 6,
        titleTextStyle: TextStyle(
          fontFamily: 'NotoSans',
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: cs.onSurface,
        ),
      ),

      // ── Bottom sheets ──
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Chips ──
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ── List tiles ──
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),

      // ── Divider ──
      dividerTheme: DividerThemeData(
        color: cs.outlineVariant,
        thickness: 1,
        space: 1,
      ),

      // ── Text ──
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
        ),
        displayMedium: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        displaySmall: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w700,
        ),
        headlineLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
          fontSize: 20,
          letterSpacing: -0.2,
        ),
        titleMedium: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        titleSmall: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        bodyLarge: TextStyle(fontFamily: 'NotoSans', fontSize: 16),
        bodyMedium: TextStyle(fontFamily: 'NotoSans', fontSize: 14),
        bodySmall: TextStyle(fontFamily: 'NotoSans', fontSize: 12),
        labelLarge: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
        labelMedium: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        labelSmall: TextStyle(
          fontFamily: 'NotoSans',
          fontWeight: FontWeight.w500,
          fontSize: 11,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeController>().mode;

    return MaterialApp.router(
      routerConfig: appRouter,
      title: 'BuildWise',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
    );
  }
}
