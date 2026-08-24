import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/features/flight_monitor/data/services/flight_log_tracker.dart';
import 'package:concorde_efb/features/flight_monitor/data/models/telemetry_model.dart';

TelemetryModel _frame({
  double ias = 0,
  double? gs,
  double vs = 0,
  double altitude = 0,
  double mach = 0,
  double lat = 0,
  double lon = 0,
  bool isLanding = false,
  List<bool> reheatActive = const [false, false, false, false],
  double? touchdownVS,
  double? touchdownPitch,
  double? touchdownGForce,
  Map<String, double> fuelTanksKg = const {},
  bool onGround = false,
}) {
  return TelemetryModel(
    timestamp: 0,
    altitude: altitude,
    ias: ias,
    tas: ias,
    gs: gs ?? ias,
    heading: 0,
    vs: vs,
    pitch: 0,
    roll: 0,
    latitude: lat,
    longitude: lon,
    gForce: 1.0,
    gearPosition: 0,
    flapsPosition: 0,
    zuluTime: '00:00:00',
    mach: mach,
    tat: 15.0,
    cgPct: 53.0,
    cgAftLimit: 59.0,
    cgFwdLimit: 52.0,
    fuelBurnTotal: 0,
    reheatActive: reheatActive,
    snootAngle: 0,
    fuelLeftTank: 0,
    fuelRightTank: 0,
    fuelCenterTank: 0,
    fuelTrimForward: 0,
    fuelTrimAft: 0,
    fuelTanksKg: fuelTanksKg,
    isLanding: isLanding,
    touchdownVS: touchdownVS ?? 0,
    touchdownPitch: touchdownPitch ?? 0,
    touchdownGForce: touchdownGForce ?? 0,
    onGround: onGround,
  );
}

FlightLogTracker _tracker({String icao = 'EGLL'}) =>
    FlightLogTracker(nearestAirportIcao: (lat, lon) => icao);

void main() {
  group('FlightLogTracker takeoff detection', () {
    test('stays grounded while onGround is true, regardless of IAS/VS', () {
      final tracker = _tracker();
      final entry = tracker.ingest(
        _frame(ias: 200, vs: 1000, onGround: true),
        DateTime(2026, 1, 1),
      );
      expect(entry, isNull);
      expect(tracker.isAirborne, isFalse);
    });

    test(
      'a rejected-takeoff bump (IAS/VS met, but still on the ground) does not trigger',
      () {
        final tracker = _tracker();
        final entry = tracker.ingest(
          _frame(ias: 180, vs: 500, onGround: true),
          DateTime(2026, 1, 1),
        );
        expect(entry, isNull);
        expect(tracker.isAirborne, isFalse);
      },
    );

    test(
      'confirmed liftoff: onGround false + IAS/VS met -- tracked, real departure attributed later',
      () {
        final tracker = _tracker();
        final entry = tracker.ingest(
          _frame(ias: 175, vs: 500, onGround: false),
          DateTime(2026, 1, 1),
        );
        expect(entry, isNull); // no entry yet -- only saved on landing
        expect(tracker.isAirborne, isTrue);
      },
    );

    test(
      'unconfirmed pickup: onGround false but IAS/VS not met still starts tracking '
      '(app/bridge connected mid-flight -- the landing must not be silently missed)',
      () {
        final tracker = _tracker();
        // Steady-level cruise: airborne per the sim, but no climb signal.
        final entry = tracker.ingest(
          _frame(ias: 530, vs: 0, mach: 2.0, onGround: false),
          DateTime(2026, 1, 1),
        );
        expect(entry, isNull);
        expect(tracker.isAirborne, isTrue);
      },
    );

    test(
      'a cruise-climb step (high IAS + positive VS) does not re-trigger once airborne',
      () {
        final tracker = _tracker();
        final start = DateTime(2026, 1, 1, 12, 0, 0);
        tracker.ingest(_frame(ias: 175, vs: 500, lat: 51, lon: 0), start);
        expect(tracker.isAirborne, isTrue);

        // Simulate a Mach 2 cruise-climb step: very high IAS, brief positive
        // VS -- exactly the pattern that would spuriously look like another
        // "takeoff" if the condition were re-evaluated every frame instead
        // of latched.
        final entry = tracker.ingest(
          _frame(ias: 530, vs: 1500, mach: 2.02, lat: 52, lon: 1),
          start.add(const Duration(hours: 2)),
        );
        expect(entry, isNull);
        expect(tracker.isAirborne, isTrue);
      },
    );
  });

  group('FlightLogTracker full flight', () {
    test('produces a completed entry with correct stats on landing', () {
      final tracker = _tracker(icao: 'EGLL');
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);

      // Takeoff at (51.0, 0.0) with 10,000 kg fuel.
      tracker.ingest(
        _frame(
          ias: 180,
          vs: 1000,
          lat: 51.0,
          lon: 0.0,
          mach: 0.3,
          altitude: 0,
          fuelTanksKg: {'11': 10000},
        ),
        t0,
      );
      expect(tracker.isAirborne, isTrue);

      // Cruise: reheat on for this frame, max mach/altitude recorded.
      tracker.ingest(
        _frame(
          ias: 530,
          vs: 0,
          lat: 52.0,
          lon: 1.0,
          mach: 2.02,
          altitude: 58000,
          reheatActive: [true, true, true, true],
          fuelTanksKg: {'11': 6000},
        ),
        t0.add(const Duration(minutes: 30)),
      );

      // Descent: reheat off.
      tracker.ingest(
        _frame(
          ias: 250,
          vs: -1500,
          lat: 53.0,
          lon: 2.0,
          mach: 0.8,
          altitude: 10000,
          fuelTanksKg: {'11': 4000},
        ),
        t0.add(const Duration(minutes: 90)),
      );

      // Touchdown.
      final entry = tracker.ingest(
        _frame(
          ias: 160,
          vs: -200,
          lat: 53.5,
          lon: 2.5,
          altitude: 100,
          isLanding: true,
          touchdownVS: -180,
          touchdownPitch: 8.5,
          touchdownGForce: 1.4,
          fuelTanksKg: {'11': 3500},
        ),
        t0.add(const Duration(minutes: 100)),
      );

      expect(entry, isNotNull);
      expect(tracker.isAirborne, isFalse);
      expect(entry!.departureIcao, 'EGLL');
      expect(entry.arrivalIcao, 'EGLL'); // fake lookup always returns this
      expect(entry.durationSeconds, const Duration(minutes: 100).inSeconds);
      expect(entry.maxMach, 2.02);
      expect(entry.maxAltitudeFt, 58000);
      expect(entry.fuelBurnedKg, closeTo(10000 - 3500, 0.01));
      expect(entry.reheatSeconds, greaterThan(0));
      expect(entry.touchdownVS, -180);
      expect(entry.touchdownPitch, 8.5);
      expect(entry.touchdownGForce, 1.4);
      expect(entry.distanceNm, greaterThan(0));
    });

    test('the isLanding pulse only produces one entry, not one per frame', () {
      final tracker = _tracker();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      tracker.ingest(_frame(ias: 180, vs: 1000, lat: 51, lon: 0), t0);

      final first = tracker.ingest(
        _frame(ias: 160, isLanding: true, lat: 51.1, lon: 0.1),
        t0.add(const Duration(minutes: 60)),
      );
      // Bridge latches isLanding true for several seconds after touchdown.
      final second = tracker.ingest(
        _frame(ias: 100, isLanding: true, lat: 51.1, lon: 0.1),
        t0.add(const Duration(minutes: 60, seconds: 1)),
      );

      expect(first, isNotNull);
      expect(second, isNull);
    });

    test('a flight that never lands never produces an entry', () {
      final tracker = _tracker();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      final entry = tracker.ingest(
        _frame(ias: 180, vs: 1000, lat: 51, lon: 0),
        t0,
      );
      expect(entry, isNull);
      expect(tracker.isAirborne, isTrue);
    });

    test('a new takeoff can be detected after a completed flight', () {
      final tracker = _tracker();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      tracker.ingest(_frame(ias: 180, vs: 1000, lat: 51, lon: 0), t0);
      tracker.ingest(
        _frame(ias: 160, isLanding: true, lat: 51.1, lon: 0.1),
        t0.add(const Duration(minutes: 60)),
      );
      expect(tracker.isAirborne, isFalse);

      final secondTakeoff = tracker.ingest(
        _frame(ias: 175, vs: 400, lat: 51.1, lon: 0.1),
        t0.add(const Duration(hours: 2)),
      );
      expect(secondTakeoff, isNull);
      expect(tracker.isAirborne, isTrue);
    });

    test(
      'a flight picked up mid-air (app connected during cruise, no climb '
      'signal before landing) still saves an entry, with departure left blank',
      () {
        final tracker = _tracker(icao: 'KJFK');
        final t0 = DateTime(2026, 1, 1, 12, 0, 0);

        // First telemetry ever seen: steady-level cruise, no climb --
        // exactly what happens if the app/bridge connects mid-flight and
        // no more cruise-climb steps occur before landing.
        tracker.ingest(
          _frame(
            ias: 530,
            vs: 0,
            mach: 2.0,
            onGround: false,
            lat: 40,
            lon: -70,
          ),
          t0,
        );
        expect(tracker.isAirborne, isTrue);

        // Straight into descent and landing -- VS never exceeds the
        // takeoff floor again, so a naive "IAS/VS only" tracker would
        // never have started tracking and would silently drop this
        // landing entirely.
        tracker.ingest(
          _frame(ias: 250, vs: -1500, mach: 0.8, lat: 40.5, lon: -73),
          t0.add(const Duration(minutes: 20)),
        );
        final entry = tracker.ingest(
          _frame(
            ias: 160,
            vs: -200,
            isLanding: true,
            lat: 40.64,
            lon: -73.78,
            touchdownVS: -150,
          ),
          t0.add(const Duration(minutes: 40)),
        );

        expect(entry, isNotNull);
        expect(entry!.departureIcao, isEmpty); // never confirmed a liftoff
        expect(entry.arrivalIcao, 'KJFK');
        expect(entry.durationSeconds, const Duration(minutes: 40).inSeconds);
        expect(entry.touchdownVS, -150);
      },
    );
  });

  group('FlightLogTracker distance integration', () {
    test(
      'integrates distance from ground speed x time, not position deltas',
      () {
        final tracker = _tracker();
        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        tracker.ingest(_frame(ias: 180, vs: 1000, gs: 180), t0);

        // 600 kt for exactly 1 hour -> 600 nm, regardless of what lat/lon
        // (left at 0,0 by the test helper) would otherwise imply.
        final entry = tracker.ingest(
          _frame(ias: 160, gs: 600, isLanding: true),
          t0.add(const Duration(hours: 1)),
        );

        expect(entry, isNotNull);
        expect(entry!.distanceNm, closeTo(600, 0.5));
      },
    );
  });

  group('FlightLogTracker stuck-airborne safety valve', () {
    test(
      'abandons tracking without saving a bogus entry past maxFlightDuration',
      () {
        final tracker = _tracker();
        final t0 = DateTime(2026, 1, 1, 12, 0, 0);
        tracker.ingest(_frame(ias: 180, vs: 1000, lat: 51, lon: 0), t0);
        expect(tracker.isAirborne, isTrue);

        final entry = tracker.ingest(
          _frame(ias: 180, lat: 51, lon: 0),
          t0.add(
            FlightLogTracker.maxFlightDuration + const Duration(minutes: 1),
          ),
        );

        expect(entry, isNull);
        expect(tracker.isAirborne, isFalse);
      },
    );

    test('a fresh takeoff can be detected right after the safety reset', () {
      final tracker = _tracker();
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      tracker.ingest(_frame(ias: 180, vs: 1000, lat: 51, lon: 0), t0);
      tracker.ingest(
        _frame(ias: 180, lat: 51, lon: 0),
        t0.add(FlightLogTracker.maxFlightDuration + const Duration(minutes: 1)),
      );
      expect(tracker.isAirborne, isFalse);

      final secondTakeoff = tracker.ingest(
        _frame(ias: 180, vs: 500, lat: 52, lon: 1),
        t0.add(FlightLogTracker.maxFlightDuration + const Duration(hours: 1)),
      );
      expect(secondTakeoff, isNull);
      expect(tracker.isAirborne, isTrue);
    });
  });
}
