import 'package:flutter/material.dart';

import 'features/estimate/estimate_page.dart';
import 'core/repositories/location_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = ThemeData(
      colorSchemeSeed: Colors.indigo,
      useMaterial3: true,
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'BuildWise',
      theme: theme,
      // 👉 Make the estimator the default entry point
      home: const EstimatePage(),
      // Optional: named route to the locations picker, if you want to jump there
      routes: {
        '/locations': (_) => const GhanaLocationsPage(),
      },
    );
  }
}

/// A lightweight Region/City browser kept as a secondary screen.
/// You can open it with: Navigator.pushNamed(context, '/locations')
class GhanaLocationsPage extends StatefulWidget {
  const GhanaLocationsPage({super.key});

  @override
  State<GhanaLocationsPage> createState() => _GhanaLocationsPageState();
}

class _GhanaLocationsPageState extends State<GhanaLocationsPage> {
  late final Future<Map<String, List<String>>> _future =
      LocationRepository().load();

  String? _selectedRegion;
  String? _selectedCity;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Region & City'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const EstimatePage()),
            ),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Estimator'),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, List<String>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Failed to load locations.\n${snap.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snap.data ?? const {};
          if (data.isEmpty) {
            return const Center(child: Text('No locations found.'));
          }

          // Regions & initial selection
          final regions = data.keys.toList()..sort();
          _selectedRegion ??= regions.first;
          final cities = List<String>.from(data[_selectedRegion] ?? [])..sort();
          _selectedCity ??= (cities.isNotEmpty ? cities.first : null);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      elevation: 1,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Use initialValue instead of deprecated value
                            DropdownButtonFormField<String>(
                              initialValue: _selectedRegion,
                              decoration: const InputDecoration(
                                labelText: 'Region',
                              ),
                              items: regions
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                if (val == null) return;
                                setState(() {
                                  _selectedRegion = val;
                                  final newCities =
                                      List<String>.from(data[val] ?? [])
                                        ..sort();
                                  _selectedCity = newCities.isNotEmpty
                                      ? newCities.first
                                      : null;
                                });
                              },
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedCity,
                              decoration: const InputDecoration(
                                labelText: 'City',
                              ),
                              items: cities
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) {
                                setState(() => _selectedCity = val);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedRegion != null)
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cities in $_selectedRegion',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: cities
                                    .map(
                                      (c) => ChoiceChip(
                                        label: Text(c),
                                        selected: c == _selectedCity,
                                        onSelected: (_) {
                                          setState(() => _selectedCity = c);
                                        },
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
