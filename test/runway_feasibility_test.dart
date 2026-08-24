import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/concorde_logic.dart';
import 'package:concorde_efb/core/concorde_constants.dart';
import 'package:concorde_efb/models/concorde_models.dart';

void main() {
  group('ConcordeLogic.snapToNonRvsm', () {
    test('leaves sub-410 levels untouched (below non-RVSM airspace)', () {
      expect(ConcordeLogic.snapToNonRvsm(350, 'E'), 350);
    });

    test('snaps to the nearest valid eastbound level', () {
      // Eastbound valid levels: 410, 450, 490, 530, 570.
      expect(ConcordeLogic.snapToNonRvsm(430, 'E'), 410);
      expect(ConcordeLogic.snapToNonRvsm(470, 'E'), 450);
    });

    test('snaps to the nearest valid westbound level', () {
      // Westbound valid levels: 430, 470, 510, 550, 590.
      expect(ConcordeLogic.snapToNonRvsm(410, 'W'), 430);
      expect(ConcordeLogic.snapToNonRvsm(590, 'W'), 590);
    });

    test('with no known direction, snaps to the nearest of either table', () {
      // 590 is only a valid westbound level; with direction unknown it
      // should still be recognized as valid rather than getting dragged
      // down to the nearest eastbound level (570).
      expect(ConcordeLogic.snapToNonRvsm(590, null), 590);
    });

    test('exact ties break toward the lower level', () {
      // 420 is equidistant between eastbound 410 and westbound 430.
      expect(ConcordeLogic.snapToNonRvsm(420, null), 410);
    });
  });

  group('ConcordeLogic.inferDirectionEW', () {
    test('LHR to JFK (westbound) infers W', () {
      // London Heathrow -> New York JFK.
      final dir = ConcordeLogic.inferDirectionEW(
        51.4700,
        -0.4543,
        40.6413,
        -73.7781,
      );
      expect(dir, 'W');
    });

    test('JFK to LHR (eastbound) infers E', () {
      final dir = ConcordeLogic.inferDirectionEW(
        40.6413,
        -73.7781,
        51.4700,
        -0.4543,
      );
      expect(dir, 'E');
    });
  });

  group('ConcordeLogic.takeoffFeasibleM', () {
    test('a long runway at MTOW with reheat is feasible', () {
      final result = ConcordeLogic.takeoffFeasibleM(
        4200,
        ConcordeConstants.weights.mtowKg,
        useReheat: true,
      );
      expect(result.feasible, isTrue);
    });

    test('a short runway is not feasible even with reheat', () {
      final result = ConcordeLogic.takeoffFeasibleM(
        1500,
        ConcordeConstants.weights.mtowKg,
        useReheat: true,
      );
      expect(result.feasible, isFalse);
    });

    test('disabling reheat increases the required runway length', () {
      final withReheat = ConcordeLogic.takeoffFeasibleM(
        3600,
        160000,
        useReheat: true,
      );
      final withoutReheat = ConcordeLogic.takeoffFeasibleM(
        3600,
        160000,
        useReheat: false,
      );
      expect(
        withoutReheat.requiredLengthMEst,
        greaterThan(withReheat.requiredLengthMEst),
      );
    });

    test(
      'no reheat above 155,000 kg is never feasible, regardless of runway length',
      () {
        final result = ConcordeLogic.takeoffFeasibleM(
          10000, // absurdly long runway
          160000,
          useReheat: false,
        );
        expect(result.feasible, isFalse);
      },
    );

    test('a headwind reduces the required takeoff distance', () {
      final calm = ConcordeLogic.takeoffFeasibleM(
        3600,
        170000,
        env: const RunwayEnvironmentInputs(headwindKt: 0),
      );
      final headwind = ConcordeLogic.takeoffFeasibleM(
        3600,
        170000,
        env: const RunwayEnvironmentInputs(headwindKt: 20),
      );
      expect(headwind.requiredLengthMEst, lessThan(calm.requiredLengthMEst));
    });

    test('a tailwind increases the required takeoff distance', () {
      final calm = ConcordeLogic.takeoffFeasibleM(
        3600,
        170000,
        env: const RunwayEnvironmentInputs(headwindKt: 0),
      );
      final tailwind = ConcordeLogic.takeoffFeasibleM(
        3600,
        170000,
        env: const RunwayEnvironmentInputs(headwindKt: -10),
      );
      expect(tailwind.requiredLengthMEst, greaterThan(calm.requiredLengthMEst));
    });

    test('a hotter-than-ISA day increases the required takeoff distance', () {
      final isa = ConcordeLogic.takeoffFeasibleM(
        3600,
        170000,
        env: const RunwayEnvironmentInputs(runwayElevFt: 0, oatC: 15),
      );
      final hot = ConcordeLogic.takeoffFeasibleM(
        3600,
        170000,
        env: const RunwayEnvironmentInputs(runwayElevFt: 0, oatC: 40),
      );
      expect(hot.requiredLengthMEst, greaterThan(isa.requiredLengthMEst));
    });
  });

  group('ConcordeLogic.landingFeasibleM', () {
    test('a long runway at MLW is feasible', () {
      final result = ConcordeLogic.landingFeasibleM(
        2500,
        ConcordeConstants.weights.mlwKg,
      );
      expect(result.feasible, isTrue);
    });

    test('a short runway is not feasible', () {
      final result = ConcordeLogic.landingFeasibleM(1000, 100000);
      expect(result.feasible, isFalse);
    });

    test(
      'a heavier landing weight requires more runway than a lighter one',
      () {
        final light = ConcordeLogic.landingFeasibleM(2500, 90000);
        final heavy = ConcordeLogic.landingFeasibleM(2500, 110000);
        expect(heavy.requiredLengthMEst, greaterThan(light.requiredLengthMEst));
      },
    );
  });

  group('ConcordeLogic.computeTakeoffSpeeds / computeLandingSpeeds', () {
    test('V1 < VR < V2 always holds', () {
      final speeds = ConcordeLogic.computeTakeoffSpeeds(170000);
      expect(speeds['V1']!, lessThan(speeds['VR']!));
      expect(speeds['VR']!, lessThan(speeds['V2']!));
    });

    test('takeoff speeds never fall below the published floors', () {
      final speeds = ConcordeLogic.computeTakeoffSpeeds(1.0); // absurdly light
      expect(speeds['V1']!, greaterThanOrEqualTo(160));
      expect(speeds['VR']!, greaterThanOrEqualTo(170));
      expect(speeds['V2']!, greaterThanOrEqualTo(190));
    });

    test('VAPP is always 15 kt above VLS once above the floor', () {
      final speeds = ConcordeLogic.computeLandingSpeeds(105000);
      expect(speeds['VAPP']! - speeds['VLS']!, closeTo(15, 0.01));
    });

    test('landing speeds never fall below the published floors', () {
      final speeds = ConcordeLogic.computeLandingSpeeds(1.0);
      expect(speeds['VLS']!, greaterThanOrEqualTo(170));
      expect(speeds['VAPP']!, greaterThanOrEqualTo(185));
    });
  });
}
