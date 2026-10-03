import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/live_flight_math.dart';
import 'package:concorde_efb/features/flight_monitor/data/models/telemetry_model.dart';

TelemetryModel _t({double gear = 0, double droop = 0}) =>
    TelemetryModel.fromJson({
      'basic': {'gearPosition': gear},
      'concorde': {'snootAngle': droop},
    });

void main() {
  group('gear / droop decoding (bridge sends 0-1 fractions)', () {
    test('gear', () {
      expect(_t(gear: 0).gearLabel, 'UP');
      expect(_t(gear: 0.5).gearLabel, 'TRANSIT');
      expect(_t(gear: 1.0).gearLabel, 'DOWN');
      expect(_t(gear: 100).gearLabel, 'DOWN'); // legacy 0-100 source
    });

    test('droop detents', () {
      expect(_t(droop: 0).droopLabel, 'UP');
      expect(_t(droop: 0.4).droopLabel, '5°');
      expect(_t(droop: 1.0).droopLabel, '12.5°');
    });
  });

  group('CG corridor vs Mach', () {
    test('moves aft with Mach', () {
      final low = cgLimitsForMach(0.3);
      final high = cgLimitsForMach(2.0);
      expect(high.fwd, greaterThan(low.fwd));
      expect(high.aft, greaterThan(low.aft));
      expect(high.aft, closeTo(59.5, 0.01));
    });

    test('a takeoff CG of 53.5 % is inside at low speed, outside at Mach 2', () {
      final low = cgLimitsForMach(0.25);
      final m2 = cgLimitsForMach(2.0);
      expect(53.5, inInclusiveRange(low.fwd, low.aft));
      expect(53.5 < m2.fwd, isTrue);
    });
  });

  group('predictToDestination', () {
    // EGLL -> KJFK, aircraft at Mach 2 cruise mid-Atlantic.
    test('mid-Atlantic cruise: TOD ahead, landing fuel sensible', () {
      final p = predictToDestination(
        lat: 50.0,
        lon: -40.0,
        destLat: 40.64,
        destLon: -73.78,
        altitudeFt: 56000,
        groundSpeedKt: 1170,
        fuelFlowKgH: 19000,
        fuelOnBoardKg: 40000,
      );
      expect(p.distToDestNm, inInclusiveRange(1400, 1700));
      expect(p.distToTodNm, closeTo(p.distToDestNm - (56000 / 300 + 30), 1));
      expect(p.timeToDestH, inInclusiveRange(1.2, 1.8));
      expect(p.fuelAtDestKg, inInclusiveRange(10000, 20000));
    });

    test('past TOD: TOD is negative, less time/fuel than a full descent', () {
      final p = predictToDestination(
        lat: 40.9,
        lon: -72.5,
        destLat: 40.64,
        destLon: -73.78,
        altitudeFt: 20000,
        groundSpeedKt: 320,
        fuelFlowKgH: 8000,
        fuelOnBoardKg: 15000,
      );
      expect(p.distToTodNm, lessThan(0));
      expect(p.fuelAtDestKg, greaterThan(13000));
    });
  });
}
