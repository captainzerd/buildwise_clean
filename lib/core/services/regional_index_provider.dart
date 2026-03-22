import 'package:flutter/foundation.dart';

import 'catalog_service.dart';

/// Provides region names and cost-index multipliers sourced from [CatalogService].
///
/// Delegates all data to the catalog so that when admin publishes new rates,
/// this provider also notifies and the estimate page rebuilds.
class RegionalIndexProvider extends ChangeNotifier {
  RegionalIndexProvider({required this.catalogService}) {
    catalogService.addListener(_onCatalogChanged);
  }

  final CatalogService catalogService;

  void _onCatalogChanged() => notifyListeners();

  /// All region names available for selection, starting with DEFAULT.
  List<String> get regionCodes {
    final keys = catalogService.regionalIndices.keys.toList();
    // Ensure DEFAULT is first.
    if (keys.contains('DEFAULT')) {
      keys.remove('DEFAULT');
      return ['DEFAULT', ...keys];
    }
    return keys;
  }

  /// Cost multiplier for [region]. Returns 1.0 for unknown regions.
  double indexFor(String? region) {
    if (region == null) return 1.0;
    return catalogService.regionalIndices[region] ?? 1.0;
  }

  @override
  void dispose() {
    catalogService.removeListener(_onCatalogChanged);
    super.dispose();
  }
}
