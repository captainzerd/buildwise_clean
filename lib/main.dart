import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/services/auth_service.dart';
import 'core/services/catalog_service.dart';
import 'core/services/fx_service.dart';
import 'core/services/complaint_service.dart';
import 'core/services/builder_profile_service.dart';
import 'core/services/contract_service.dart';
import 'core/state/theme_mode_controller.dart';
import 'core/services/project_service.dart';
import 'core/services/vendor_service.dart';
import 'core/services/regional_index_provider.dart';
import 'core/storage/storage_service.dart';
import 'features/estimate/state/estimate_controller.dart';
import 'features/shell/home_shell.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
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

  // ── Services ──
  final storage = StorageService();
  final catalog = CatalogService();

  // RegionalIndexProvider delegates to CatalogService.
  final regional = RegionalIndexProvider(catalogService: catalog);

  // FxService: load cached rates immediately, refresh in background.
  final fx = FxService();
  await fx.warmUp();

  final auth = AuthService();
  await auth.init();

  final projectService = ProjectService();
  final builderProfileService = BuilderProfileService();
  final contractService = ContractService();
  final vendorService = VendorService();
  final complaintService = ComplaintService();
  final themeModeController = ThemeModeController();

  runApp(
    AppRoot(
      storage: storage,
      catalog: catalog,
      regional: regional,
      fx: fx,
      auth: auth,
      projectService: projectService,
      builderProfileService: builderProfileService,
      contractService: contractService,
      vendorService: vendorService,
      complaintService: complaintService,
      themeModeController: themeModeController,
    ),
  );
}

class AppRoot extends StatelessWidget {
  const AppRoot({
    super.key,
    required this.storage,
    required this.catalog,
    required this.regional,
    required this.fx,
    required this.auth,
    required this.projectService,
    required this.builderProfileService,
    required this.contractService,
    required this.vendorService,
    required this.complaintService,
    required this.themeModeController,
  });

  final StorageService storage;
  final CatalogService catalog;
  final RegionalIndexProvider regional;
  final FxService fx;
  final AuthService auth;
  final ProjectService projectService;
  final BuilderProfileService builderProfileService;
  final ContractService contractService;
  final VendorService vendorService;
  final ComplaintService complaintService;
  final ThemeModeController themeModeController;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<StorageService>.value(value: storage),
        ChangeNotifierProvider<CatalogService>.value(value: catalog),
        ChangeNotifierProvider<RegionalIndexProvider>.value(value: regional),
        // FxService is now a ChangeNotifier — widgets can watch it for rate updates.
        ChangeNotifierProvider<FxService>.value(value: fx),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        Provider<ProjectService>.value(value: projectService),
        ChangeNotifierProvider<BuilderProfileService>.value(value: builderProfileService),
        Provider<ContractService>.value(value: contractService),
        ChangeNotifierProvider<VendorService>.value(value: vendorService),
        Provider<ComplaintService>.value(value: complaintService),
        ChangeNotifierProvider<ThemeModeController>.value(
          value: themeModeController,
        ),
        ChangeNotifierProvider<EstimateController>(
          lazy: false,
          create: (ctx) => EstimateController(
            catalogService: ctx.read<CatalogService>(),
            regionalIndexProvider: ctx.read<RegionalIndexProvider>(),
            fxService: ctx.read<FxService>(),
            storageService: ctx.read<StorageService>(),
          ),
        ),
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

  @override
  Widget build(BuildContext context) {
    final themeMode = context.watch<ThemeModeController>().mode;

    return MaterialApp(
      title: 'BuildWise',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.indigo,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: const HomeShell(),
    );
  }
}
