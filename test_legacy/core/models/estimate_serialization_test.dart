import 'package:flutter_test/flutter_test.dart';
import 'package:buildwise/core/models/estimate.dart';

void main() {
  test('Estimate JSON round-trip', () {
    final e = Estimate(
      id: 'E1',
      projectName: 'House A',
      squareFootage: 200,
      region: 'Greater Accra',
      city: 'Accra',
      breakdown: const {'Foundation': 1000, 'Roofing': 500},
      totalCost: 1500,
      createdAt: DateTime(2024, 5, 1),
    );

    final json = e.toJson();
    final copy = Estimate.fromJson(json);

    expect(copy.id, e.id);
    expect(copy.projectName, e.projectName);
    expect(copy.breakdown, e.breakdown);
    expect(copy.totalCost, e.totalCost);
    expect(copy.createdAt, e.createdAt);
  });
}
