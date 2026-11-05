import 'dart:io';

import 'package:concorde_efb/features/flight_monitor/data/models/telemetry_model.dart';
import 'package:concorde_efb/features/logbook/data/flight_log.dart';
import 'package:concorde_efb/features/logbook/data/logbook_repository.dart';
import 'package:concorde_efb/features/logbook/domain/flight_tracker.dart';
import 'package:concorde_efb/features/logbook/domain/landing_rating.dart';
import 'package:flutter_test/flutter_test.dart';

final _t0 = DateTime.utc(2026, 11, 2, 14, 12, 0);

TelemetryModel frame(
  int sec, {
  bool ground = true,
  bool engines = true,
  double alt = 100,
  double ias = 0,
  double gs = 0,
  double vs = 0,
  double mach = 0,
  double fuel = 16000,
  bool reheat = false,
  bool landing = false,
  double tdVs = 0,
  double tdG = 0,
}) {
  final z = _t0.add(Duration(seconds: sec));
  String p(int n) => n.toString().padLeft(2, '0');
  return TelemetryModel.fromJson({
    'timestamp': sec,
    'basic': {
      'altitude': alt,
      'ias': ias,
      'gs': gs,
      'vs': vs,
      'pitch': 5.0,
      'latitude': 51.47,
      'longitude': -0.45,
      'gForce': 1.2,
      'zuluTime': '${p(z.hour)}:${p(z.minute)}:${p(z.second)}',
    },
    'concorde': {
      'mach': mach,
      'engineFuelFlowKgH': engines ? [5000, 5000, 5000, 5000] : [0, 0, 0, 0],
      'reheatActive': [reheat, reheat, reheat, reheat],
      'fuelTanksKg': {'11': fuel},
    },
    'events': {
      'isLanding': landing,
      'touchdownVS': tdVs,
      'touchdownGForce': tdG,
      'touchdownPitch': 11.0,
      'onGround': ground,
    },
  });
}

TrackerEvent? feed(
  FlightTracker tr,
  TelemetryModel t,
  int sec, [
  List<String> alerts = const [],
]) => tr.update(
  t,
  _t0.add(Duration(seconds: sec)),
  TrackerContext(
    callSign: 'BAW1',
    plannedDep: 'EGLL',
    plannedArr: 'KJFK',
    zfwKg: 90000,
    alertTexts: alerts,
    nearestAirport: (_, _) => 'EGLL',
  ),
);

void main() {
  test('landing rating thresholds', () {
    expect(rateLanding(100, 1.1), LandingRating.butter);
    expect(rateLanding(-200, 1.1), LandingRating.smooth);
    expect(rateLanding(300, 1.1), LandingRating.firm);
    expect(rateLanding(500, 1.1), LandingRating.hard);
    expect(rateLanding(600, 1.1), LandingRating.inspection);
    expect(rateLanding(100, 2.6), LandingRating.inspection);
    expect(LandingRating.inspection.label, 'INSPECTION');
  });

  test('full flight', () {
    final tr = FlightTracker();
    expect(feed(tr, frame(0), 0), TrackerEvent.blockOut);
    expect(tr.current!.id, 'BAW1-20261102T1412Z');
    expect(
      feed(tr, frame(60, ground: false, ias: 160, alt: 300, fuel: 15000), 60),
      TrackerEvent.takeoff,
    );
    expect(tr.current!.actualDep, 'EGLL');
    for (var s = 61; s <= 200; s += 1) {
      feed(
        tr,
        frame(
          s,
          ground: false,
          ias: 400,
          gs: 1200,
          alt: 55000,
          mach: 2.0,
          reheat: s < 100,
          vs: -50,
          fuel: 9000,
        ),
        s,
        s == 100 ? ['MACH'] : [],
      );
    }
    feed(
      tr,
      frame(
        201,
        ground: false,
        ias: 160,
        gs: 160,
        alt: 100,
        vs: -700,
        fuel: 6000,
      ),
      201,
    );
    expect(
      feed(
        tr,
        frame(202, landing: true, tdVs: -350, tdG: 1.6, fuel: 6000),
        202,
      ),
      TrackerEvent.touchdown,
    );
    expect(tr.current!.touchdownFpm, 350);
    expect(tr.current!.landingRating, LandingRating.firm);
    feed(tr, frame(203, ground: false, alt: 20, ias: 150, fuel: 6000), 203);
    feed(tr, frame(204, ground: true, ias: 140, fuel: 6000), 204);
    expect(tr.current!.bounces, 1);
    feed(tr, frame(220, engines: false, fuel: 5000), 220);
    feed(tr, frame(222, engines: false, fuel: 5000), 222);
    expect(
      feed(tr, frame(223, engines: false, fuel: 5000), 223),
      TrackerEvent.blockIn,
    );

    final l = tr.current!;
    expect(l.takeoff, _t0.add(const Duration(seconds: 60)));
    final f0 = FlightTracker.fuelKg(frame(0));
    final f1 = FlightTracker.fuelKg(frame(0, fuel: 5000));
    expect(f0, greaterThan(f1));
    expect(l.fuelBlockOutKg, f0);
    expect(l.fuelBurnedKg, closeTo(f0 - f1, 0.01));
    expect(l.towKg, 90000 + l.fuelTakeoffKg!);
    expect(l.maxMach, 2.0);
    expect(l.supersonicSec, greaterThan(100));
    expect(l.reheatSec, greaterThan(30));
    expect(l.distanceNm, greaterThan(30));
    expect(l.alerts, {'MACH': 1});
    expect(l.track, isNotEmpty);
    expect(l.blockTime, const Duration(seconds: 223));
    expect(tr.phase, TrackerPhase.done);
  });

  test('a second flight starts after block-in', () {
    final tr = FlightTracker();
    feed(tr, frame(0), 0);
    feed(tr, frame(60, ground: false, ias: 160, alt: 300), 60);
    feed(tr, frame(120, landing: true, tdVs: -150, tdG: 1.2), 120);
    for (final s in [130, 132, 134]) {
      feed(tr, frame(s, engines: false), s);
    }
    expect(tr.phase, TrackerPhase.done);
    expect(feed(tr, frame(200, engines: false), 200), isNull);
    expect(feed(tr, frame(300), 300), TrackerEvent.blockOut);
    expect(tr.current!.id, 'BAW1-20261102T1417Z');
  });

  test('shutdown before takeoff discards', () {
    final tr = FlightTracker();
    feed(tr, frame(0), 0);
    expect(feed(tr, frame(10, engines: false), 10), TrackerEvent.discarded);
    expect(tr.current, isNull);
    expect(tr.phase, TrackerPhase.idle);
  });

  test('go-around discards touchdown', () {
    final tr = FlightTracker();
    feed(tr, frame(0), 0);
    feed(tr, frame(10, ground: false, ias: 160, alt: 300), 10);
    feed(tr, frame(20, ground: false, ias: 150, alt: 50, vs: -300), 20);
    expect(feed(tr, frame(21), 21), TrackerEvent.touchdown);
    feed(tr, frame(22, ground: false, ias: 150, alt: 100), 22);
    expect(
      feed(tr, frame(38, ground: false, ias: 200, alt: 900), 38),
      TrackerEvent.goAround,
    );
    expect(tr.current!.touchdown, isNull);
    expect(tr.phase, TrackerPhase.airborne);
  });

  test('json round trip, repository, csv', () async {
    final tr = FlightTracker();
    feed(tr, frame(0), 0);
    final log = tr.current!;
    expect(FlightLog.fromJson(log.toJson()).toJson(), log.toJson());

    final dir = await Directory.systemTemp.createTemp('logbook_test');
    addTearDown(() => dir.delete(recursive: true));
    final repo = LogbookRepository(dir);
    await repo.save(log);
    File('${dir.path}/bad.json').writeAsStringSync('{nope');
    final all = await repo.list();
    expect(all.map((l) => l.id), [log.id]);
    final csv = LogbookRepository.exportCsv(all);
    expect(
      csv.split('\n').first,
      startsWith('date,callsign,registration,dep,arr'),
    );
    expect(csv, contains('BAW1'));
    expect(LogbookRepository.exportJson(all), contains(log.id));
    await repo.delete(log.id);
    expect(await repo.list(), isEmpty);
  });

  test('measures takeoff and landing roll', () {
    final tr = FlightTracker();
    feed(tr, frame(0), 0); // block out
    feed(tr, frame(1, gs: 10), 1); // taxi, no takeoff thrust
    // Reheat lit at 2 s, ground speed 0 -> 200 kt over 40 s (5 kt/s).
    for (var s = 2; s <= 42; s++) {
      feed(
        tr,
        frame(s, reheat: true, gs: (s - 2) * 5.0, ias: (s - 2) * 5.0),
        s,
      );
    }
    expect(
      feed(tr, frame(43, ground: false, ias: 205, gs: 205, alt: 300), 43),
      TrackerEvent.takeoff,
    );
    final to = tr.current!.takeoffPerf!;
    // Sum of 5..200 kt at 1 s steps = 4,100 kt*s = ~2,109 m.
    expect(to['rollM'] as num, closeTo(2109, 5));
    expect(to['liftoffIas'], 205);
    expect((to['trace'] as List).length, greaterThan(30));

    feed(tr, frame(100, ground: false, ias: 180, gs: 180, alt: 200), 100);
    expect(
      feed(tr, frame(101, ias: 170, gs: 170, landing: true), 101),
      TrackerEvent.touchdown,
    );
    // Decelerate 170 -> 30 kt at 10 kt/s.
    for (var s = 102; s <= 116; s++) {
      feed(tr, frame(s, gs: 170 - (s - 101) * 10.0), s);
    }
    final ld = tr.current!.landingPerf!;
    expect(ld['rollToExitM'] as num, greaterThan(500));
    expect(ld['touchdownIas'], 180);
  });
}
