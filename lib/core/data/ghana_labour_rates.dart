/// 2024 standard daily labour rates in Ghana (GH₵).
/// Source: GhBC / MESW prevailing wage guidelines.
abstract final class GhanaLabourRates {
  static const Map<String, double> dailyRates = {
    'Mason': 150,
    'Steel Fixer': 175,
    'Carpenter': 155,
    'Electrician': 200,
    'Plumber': 190,
    'Painter': 130,
    'Unskilled Labour': 90,
  };
}
