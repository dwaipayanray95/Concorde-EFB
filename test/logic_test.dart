import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/concorde_logic.dart';

void main() {
  group('ConcordeLogic Tests', () {
    test('Altitude Burn Factor should be lower at higher FL', () {
      final f450 = ConcordeLogic.altitudeBurnFactor(450);
      final f600 = ConcordeLogic.altitudeBurnFactor(600);
      
      expect(f600, lessThan(f450));
      expect(f450, closeTo(1.2, 0.01));
      expect(f600, closeTo(1.0, 0.01));
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
