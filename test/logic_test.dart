import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/concorde_logic.dart';

void main() {
  group('ConcordeLogic Tests', () {
    test('Cruise fuel flow should taper down at higher FL', () {
      final f500 = ConcordeLogic.cruiseFuelFlowKgHAtFL(500);
      final f600 = ConcordeLogic.cruiseFuelFlowKgHAtFL(600);

      expect(f600, lessThan(f500));
      expect(f600, closeTo(17000, 1));
    });

    test('Mission trip fuel for a long transatlantic sector should not exceed tank capacity', () {
      // JFK-EDDM class sector (~3630 nm) at max cruise FL -- this is the
      // exact case that used to compute ~114,000 kg, above the 95,681 kg
      // the aircraft can actually carry.
      final profile = ConcordeLogic.buildCruiseMissionProfile(3630, 590);
      expect(profile.tripKg, lessThan(95681));
    });

    test('Mission Profile trip fuel should scale with distance', () {
      final p1000 = ConcordeLogic.buildCruiseMissionProfile(1000, 580);
      final p2000 = ConcordeLogic.buildCruiseMissionProfile(2000, 580);
      
      expect(p2000.tripKg, greaterThan(p1000.tripKg));
      expect(p2000.tripKg, lessThan(p1000.tripKg * 2.5));
    });

    test('V-Speeds should scale with weight', () {
      final speedsLow = ConcordeLogic.computeTakeoffSpeeds(140000);
      final speedsHigh = ConcordeLogic.computeTakeoffSpeeds(180000);
      
      expect(speedsHigh['V1'], greaterThan(speedsLow['V1']!));
      expect(speedsHigh['VR'], greaterThan(speedsLow['VR']!));
      expect(speedsHigh['V2'], greaterThan(speedsLow['V2']!));
    });
  });
}
