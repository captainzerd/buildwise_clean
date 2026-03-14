// lib/app.dart
import 'package:flutter/material.dart';

class WyseBrixApp extends StatelessWidget {
  final bool useCloud;
  final Object? authService;
  final Object? catalogService;
  final Object? regionalIndexProvider;
  final Object? fxService;
  final Object? storageService;

  const WyseBrixApp({
    super.key,
    required this.useCloud,
    this.authService,
    this.catalogService,
    this.regionalIndexProvider,
    this.fxService,
    this.storageService,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WyseBrix',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const Scaffold(
        body: Center(child: Text('WyseBrix is wiring up…')),
      ),
    );
  }
}
