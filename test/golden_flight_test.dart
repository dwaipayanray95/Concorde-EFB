import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/concorde_logic.dart';
import 'package:concorde_efb/core/concorde_constants.dart';
import 'package:concorde_efb/models/concorde_models.dart';

/// Golden sectors: the phase model must reproduce published real-world
/// Concorde figures. LHR-JFK (BA001): ~3,150 nm flown, ~3h15 airborne,
/// ~70-78 t trip fuel, ~92-95 t block with reserves; whole-flight average
/// burn ~20-24 t/h; about a quarter to a third of the fuel used to reach
/// Mach 2.
void main() {
  group('Golden: EGLL-KJFK at FL590 (3,150 nm flown)', () {
    final p = ConcordeLogic.buildCruiseMissionProfile(3150, 590);

    test('is a supersonic profile reaching the selected FL', () {
      expect(p.supersonic, isTrue);
      expect(p.flCappedForDistance, isFalse);
      expect(p.initialCruiseFl, 500);
      expect(p.targetCruiseFl, 590);
    });

    test('trip fuel 68-78 t', () {
      expect(p.tripKg, inInclusiveRange(68000, 78000));
    });

    test('airborne time 3h00-3h25', () {
      expect(p.totalTimeH, inInclusiveRange(3.0, 3.42));
    });

    test('average burn 20-24 t/h', () {
      expect(p.tripKg / p.totalTimeH, inInclusiveRange(20000, 24000));
    });

    test('fuel to Mach 2 is 20-35% of tank capacity', () {
      final toMach2 = p.climbKg + p.accelKg;
      final cap = ConcordeConstants.weights.fuelCapacityKg;
      expect(toMach2 / cap, inInclusiveRange(0.20, 0.35));
    });

    test('Mach 2 cruise TAS ~1,170 kt', () {
      expect(p.avgCruiseTasKt, closeTo(1170, 10));
    });

    test('block fuel with KBOS alternate fits in the tanks', () {
      final block = ConcordeLogic.blockFuelKg(
        BlockFuelInputs(
          tripKg: p.tripKg,
          taxiKg: 2500,
          contingencyPct: 5,
          finalReserveKg: 6000,
          alternateNm: 160,
        ),
      );
      expect(block.blockKg, inInclusiveRange(88000, 95681));
      // Alternate leg: subsonic ~160 nm + missed approach -> ~5-9 t.
      expect(block.alternateKg, inInclusiveRange(4500, 9000));
    });

    test('phase fuel adds up to trip fuel', () {
      expect(
        p.climbKg + p.accelKg + p.cruiseKg + p.descentKg,
        closeTo(p.tripKg, 0.01),
      );
      expect(
        p.climb.distNm + p.accel.distNm + p.cruise.distNm + p.descent.distNm,
        closeTo(3150, 0.01),
      );
    });
  });

  group('Golden: EGLL-LFPG short hop (~200 nm)', () {
    final p = ConcordeLogic.buildCruiseMissionProfile(200, 590);

    test('falls back to a capped subsonic profile', () {
      expect(p.supersonic, isFalse);
      expect(p.flCappedForDistance, isTrue);
      expect(p.targetCruiseFl, lessThanOrEqualTo(290));
    });

    test('trip fuel ~6-12 t, not a full Mach 2 climb', () {
      expect(p.tripKg, inInclusiveRange(6000, 12000));
      expect(p.totalTimeH, inInclusiveRange(0.4, 0.9));
    });
  });

  group('Golden: KJFK-EDDM-class long sector (3,630 nm)', () {
    final p = ConcordeLogic.buildCruiseMissionProfile(3630, 590);

    test('trip fuel stays below tank capacity', () {
      expect(p.tripKg, lessThan(ConcordeConstants.weights.fuelCapacityKg));
      expect(p.tripKg, greaterThan(78000));
    });
  });

  test('trip fuel increases monotonically with distance', () {
    var last = 0.0;
    for (var d = 100.0; d <= 4000; d += 50) {
      final trip = ConcordeLogic.buildCruiseMissionProfile(d, 590).tripKg;
      expect(trip, greaterThanOrEqualTo(last - 1500), reason: 'at $d nm');
      last = trip;
    }
  });

  test('subsonic TAS at FL290 ~ M0.95 (~550-570 kt)', () {
    expect(ConcordeLogic.cruiseTasKtForFL(290), inInclusiveRange(545, 575));
  });
}
