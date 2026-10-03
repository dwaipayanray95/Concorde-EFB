import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/live_flight_math.dart';
import 'package:concorde_efb/core/concorde_logic.dart';
import 'package:concorde_efb/core/route_math.dart';
import 'package:concorde_efb/models/concorde_models.dart';
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
      expect(high.aft, closeTo(59.2, 0.01));
    });

    test('targets match the DC Designs manual (54 % takeoff, 59 % Mach 2)', () {
      expect(cgTargetForMach(0.3), closeTo(53.5, 0.3));
      expect(cgTargetForMach(2.0), closeTo(59.0, 0.01));
      for (var m = 0.0; m <= 2.2; m += 0.05) {
        final lim = cgLimitsForMach(m);
        expect(cgTargetForMach(m), inInclusiveRange(lim.fwd, lim.aft));
      }
    });

    test(
      'a takeoff CG of 53.5 % is inside at low speed, outside at Mach 2',
      () {
        final low = cgLimitsForMach(0.25);
        final m2 = cgLimitsForMach(2.0);
        expect(53.5, inInclusiveRange(low.fwd, low.aft));
        expect(53.5 < m2.fwd, isTrue);
      },
    );
  });

  group('predictToDestination', () {
    // EGLL -> KJFK, aircraft at Mach 2 cruise mid-Atlantic.
    test('mid-Atlantic cruise: TOD ahead, landing fuel sensible', () {
      final p = predictToDestination(
        distToDestNm: 1550,
        altitudeFt: 56000,
        groundSpeedKt: 1170,
        fuelFlowKgH: 19000,
        fuelOnBoardKg: 40000,
      );
      expect(p.distToDestNm, 1550);
      expect(p.distToTodNm, closeTo(p.distToDestNm - (56000 / 300 + 30), 1));
      expect(p.timeToDestH, inInclusiveRange(1.2, 1.8));
      expect(p.fuelAtDestKg, inInclusiveRange(10000, 20000));
    });

    test('past TOD: TOD is negative, less time/fuel than a full descent', () {
      final p = predictToDestination(
        distToDestNm: 62,
        altitudeFt: 20000,
        groundSpeedKt: 320,
        fuelFlowKgH: 8000,
        fuelOnBoardKg: 15000,
      );
      expect(p.distToTodNm, lessThan(0));
      expect(p.fuelAtDestKg, greaterThan(13000));
    });
  });

  group('RouteMath', () {
    // A dog-leg route: the flown distance is longer than the great circle.
    const route = [
      RoutePoint('A', 50.0, 0.0),
      RoutePoint('B', 52.0, -5.0),
      RoutePoint('C', 50.0, -10.0),
    ];

    test(
      'polyline length is the sum of legs, longer than the great circle',
      () {
        final legs =
            ConcordeLogic.greatCircleNM(50, 0, 52, -5) +
            ConcordeLogic.greatCircleNM(52, -5, 50, -10);
        expect(RouteMath.polylineNm(route), closeTo(legs, 0.01));
        expect(
          RouteMath.polylineNm(route),
          greaterThan(ConcordeLogic.greatCircleNM(50, 0, 50, -10)),
        );
      },
    );

    test('remaining distance follows the route, not the great circle', () {
      // At A: the whole route remains.
      expect(
        RouteMath.remainingAlongRouteNm(50.0, 0.0, route),
        closeTo(RouteMath.polylineNm(route), 0.5),
      );
      // Halfway along the first leg.
      final remaining = RouteMath.remainingAlongRouteNm(51.0, -2.5, route);
      final secondLeg = ConcordeLogic.greatCircleNM(52, -5, 50, -10);
      expect(remaining, greaterThan(secondLeg));
      expect(
        remaining,
        greaterThan(ConcordeLogic.greatCircleNM(51, -2.5, 50, -10)),
      );
      // At C: nothing left.
      expect(
        RouteMath.remainingAlongRouteNm(50.0, -10.0, route),
        closeTo(0, 0.5),
      );
    });
  });
}
