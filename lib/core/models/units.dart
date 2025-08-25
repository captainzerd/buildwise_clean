/// Display + conversion helpers for the app's length/area units.
enum LengthUnit { meters, feet }

extension LengthUnitX on LengthUnit {
  /// Short programmatic code.
  String get code => switch (this) {
        LengthUnit.meters => 'm',
        LengthUnit.feet => 'ft',
      };

  /// Label for height fields.
  String get lengthLabel => switch (this) {
        LengthUnit.meters => 'm',
        LengthUnit.feet => 'ft',
      };

  /// Label for area fields.
  String get areaLabel => switch (this) {
        LengthUnit.meters => 'm²',
        LengthUnit.feet => 'ft²',
      };

  // --- length conversions ---
  double toMeters(double value) => switch (this) {
        LengthUnit.meters => value,
        LengthUnit.feet => value * 0.3048,
      };

  double fromMeters(double meters) => switch (this) {
        LengthUnit.meters => meters,
        LengthUnit.feet => meters / 0.3048,
      };

  // --- area conversions ---
  double areaToSqm(double value) => switch (this) {
        LengthUnit.meters => value, // already m²
        LengthUnit.feet => value * 0.09290304, // ft² -> m²
      };

  double areaFromSqm(double sqm) => switch (this) {
        LengthUnit.meters => sqm,
        LengthUnit.feet => sqm / 0.09290304, // m² -> ft²
      };

  /// Parse from short code (e.g., "m", "ft"). Defaults to meters.
  static LengthUnit fromCode(String? code) {
    switch ((code ?? '').toLowerCase()) {
      case 'ft':
      case 'feet':
        return LengthUnit.feet;
      default:
        return LengthUnit.meters;
    }
  }
}
