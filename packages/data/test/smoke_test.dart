import 'package:test/test.dart';
import 'package:buildwise_domain/buildwise_domain.dart';
import 'package:buildwise_data/buildwise_data.dart';

void main() {
  test('estimate repo memory', () async {
    final repo = EstimateRepositoryMemory();
    final est = Estimate(
      id: '1',
      projectName: 'P',
      phaseBudget: {'foundation': 100},
    );
    await repo.save(est);
    expect((await repo.getById('1'))?.total, 100);
  });
}
