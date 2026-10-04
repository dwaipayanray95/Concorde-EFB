import 'package:concorde_efb/core/concorde_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('long sector: highest supersonic FL, SimBrief FL ignored', () {
    expect(
      ConcordeLogic.plannedCruiseFl(3150, direction: 'W', simbriefFl: 370),
      590,
    );
    expect(ConcordeLogic.plannedCruiseFl(3150, direction: 'E'), 570);
  });

  test('borderline sector: lower supersonic FL that still fits', () {
    final fl = ConcordeLogic.plannedCruiseFl(580, direction: 'E');
    expect(fl, greaterThanOrEqualTo(410));
    expect(
      580,
      greaterThanOrEqualTo(ConcordeLogic.minSupersonicDistanceNm(fl)),
    );
  });

  test('short sector: SimBrief FL kept when it fits and is high enough', () {
    expect(
      ConcordeLogic.plannedCruiseFl(400, direction: 'E', simbriefFl: 330),
      330,
    );
  });

  test('short sector: low SimBrief FL raised to the suggested FL290', () {
    expect(
      ConcordeLogic.plannedCruiseFl(400, direction: 'E', simbriefFl: 230),
      290,
    );
    expect(
      ConcordeLogic.plannedCruiseFl(400, direction: 'W', simbriefFl: 220),
      280,
    );
  });

  test('very short sector: capped to what fits, right parity', () {
    // 120 nm fits ~FL100 at most.
    final fl = ConcordeLogic.plannedCruiseFl(
      120,
      direction: 'E',
      simbriefFl: 330,
    );
    expect(fl, lessThanOrEqualTo(ConcordeLogic.maxSubsonicFlForDistance(120)));
    expect((fl ~/ 10).isOdd, isTrue);
  });
}
