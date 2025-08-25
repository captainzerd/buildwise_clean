// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/services/catalog_service.dart';
import 'core/services/regional_index_provider.dart';
import 'core/services/fx_service.dart';
import 'core/storage/storage_service.dart';
import 'core/services/pdf_service.dart';
import 'core/services/telemetry.dart';

import 'features/estimate/state/estimate_controller.dart';
import 'features/estimate/estimate_page.dart';
import 'features/saved/saved_estimates_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BuildWiseApp());
}

class BuildWiseApp extends StatelessWidget {
  const BuildWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider(create: (_) => CatalogService()),
        Provider(create: (_) => RegionalIndexProvider()),
        Provider(create: (_) => FxService()),
        Provider(create: (_) => StorageService()),
        Provider(create: (_) => PdfService()),
        Provider.value(value: Telemetry.I),
        ChangeNotifierProvider(
          create: (ctx) => EstimateController(
            catalogService: ctx.read<CatalogService>(),
            regionalIndexProvider: ctx.read<RegionalIndexProvider>(),
            fxService: ctx.read<FxService>(),
            storageService: ctx.read<StorageService>(),
          )..init(),
        ),
      ],
      child: MaterialApp(
        title: 'BuildWise',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        routes: {
          '/': (_) => const EstimatePage(),
          '/saved': (_) => const SavedEstimatesPage(),
        },
      ),
    );
  }
}
