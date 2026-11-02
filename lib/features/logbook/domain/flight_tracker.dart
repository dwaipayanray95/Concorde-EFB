import '../../../core/concorde_fuel_schematic.dart';
import '../../flight_monitor/data/models/telemetry_model.dart';
import '../data/flight_log.dart';

enum TrackerPhase { idle, taxiOut, airborne, landed, done }

/// What just happened; the caller persists [FlightTracker.current] on all but
/// [discarded] (which means "no flight": delete/ignore the log).
enum TrackerEvent { blockOut, takeoff, touchdown, goAround, blockIn, discarded }

/// Plan snapshot + live helpers the tracker needs (kept out of the tracker
/// so it stays free of Riverpod / IO).
class TrackerContext {
  final String callSign, registration, plannedDep, plannedArr, alternate;
  final String planSource;
  final double plannedTimeH, plannedTripKg, cruiseFl, finalReserveKg, zfwKg;
  final List<String> alertTexts;

  /// ICAO of the airport within 10 nm of the point, else null.
  final String? Function(double lat, double lon) nearestAirport;

  const TrackerContext({
    this.callSign = '',
    this.registration = '',
    this.plannedDep = '',
    this.plannedArr = '',
    this.alternate = '',
    this.planSource = '',
    this.plannedTimeH = 0,
    this.plannedTripKg = 0,
    this.cruiseFl = 0,
    this.finalReserveKg = 0,
    this.zfwKg = 0,
    this.alertTexts = const [],
    this.nearestAirport = _noAirport,
  });
  static String? _noAirport(double a, double b) => null;
}

/// Block-out -> takeoff -> touchdown -> block-in state machine over live
/// telemetry. Feed every frame to [update]; read [current] for the log.
class FlightTracker {
  static const _sampleEvery = Duration(seconds: 5);
  static const _bounceWindow = Duration(seconds: 5);
  static const _goAroundAfter = Duration(seconds: 15);
  static const _shutdownFor = Duration(seconds: 3);

  TrackerPhase phase = TrackerPhase.idle;

  // Milestone fields live in [_base]; per-frame stats in the accumulators
  // below (merged in [current]) so frames never rebuild the whole log.
  FlightLog? _base;
  double _maxMach = 0, _maxAlt = 0, _ssSec = 0, _rhSec = 0, _dist = 0;
  final Map<String, int> _alerts = {};
  final List<List<num>> _track = [];

  DateTime? _lastNow, _lastSample, _airborneSince, _stoppedSince, _touchdownNow;
  DateTime _updatedAt = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  bool _wasOnGround = true;
  Set<String> _prevAlerts = {};
  // Last airborne frame, for touchdown figures when the bridge didn't latch.
  TelemetryModel? _lastAir;

  FlightLog? get current {
    final b = _base;
    if (b == null) return null;
    return FlightLog.fromJson({
      ...b.toJson(),
      'updatedAt': _updatedAt.toIso8601String(),
      'maxMach': _maxMach,
      'maxAltFt': _maxAlt,
      'supersonicSec': _ssSec,
      'reheatSec': _rhSec,
      'distanceNm': _dist,
      'alerts': _alerts,
      'track': _track,
    });
  }

  static bool enginesRunning(TelemetryModel t) =>
      t.engineFuelFlowKgH.length >= 4
      ? t.engineFuelFlowKgH.any((f) => f > 150)
      : t.fuelBurnTotal > 600;

  static double fuelKg(TelemetryModel t) => ConcordeFuelSchematic.totalFuelKg(
    ConcordeFuelSchematic.computeTankFills(t),
  );

  /// Device date + sim zulu clock, nudged across midnight.
  static DateTime zulu(TelemetryModel t, DateTime nowUtc) {
    final p = t.zuluTime.split(':').map((s) => int.tryParse(s) ?? 0).toList();
    if (p.length < 3) return nowUtc;
    var d = DateTime.utc(
      nowUtc.year,
      nowUtc.month,
      nowUtc.day,
      p[0],
      p[1],
      p[2],
    );
    if (d.difference(nowUtc) > const Duration(hours: 12)) {
      d = d.subtract(const Duration(days: 1));
    } else if (nowUtc.difference(d) > const Duration(hours: 12)) {
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  void _reset() {
    phase = TrackerPhase.idle;
    _base = null;
    _maxMach = _maxAlt = _ssSec = _rhSec = _dist = 0;
    _alerts.clear();
    _track.clear();
    _lastSample = _airborneSince = _stoppedSince = _touchdownNow = null;
    _lastAir = null;
    _prevAlerts = {};
  }

  void _patch(Map<String, Object?> m) {
    _base = FlightLog.fromJson({
      ..._base!.toJson(),
      for (final e in m.entries)
        e.key: e.value is DateTime
            ? (e.value as DateTime).toIso8601String()
            : e.value,
    });
  }

  List<num> _point(TelemetryModel t, DateTime z) => [
    z.millisecondsSinceEpoch ~/ 1000,
    double.parse(t.latitude.toStringAsFixed(5)),
    double.parse(t.longitude.toStringAsFixed(5)),
    t.altitude.round(),
    t.gs.round(),
  ];

  static String _stamp(DateTime z) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${z.year}${p(z.month)}${p(z.day)}T${p(z.hour)}${p(z.minute)}Z';
  }

  TrackerEvent? update(TelemetryModel t, DateTime nowUtc, TrackerContext ctx) {
    if (!t.flightLoaded) return null;
    // The last flight was saved at block-in; the next engine start begins a
    // new one (engines are off here, so this just re-arms the idle state).
    if (phase == TrackerPhase.done) _reset();
    final running = enginesRunning(t);
    final z = zulu(t, nowUtc);
    final dt = _lastNow == null
        ? 0.0
        : nowUtc.difference(_lastNow!).inMilliseconds.clamp(0, 5000) / 1000;
    _lastNow = nowUtc;
    final wasOnGround = _wasOnGround;
    _wasOnGround = t.onGround;
    _updatedAt = nowUtc;

    if (phase == TrackerPhase.idle) {
      if (!(t.onGround && running)) return null;
      phase = TrackerPhase.taxiOut;
      final cs = ctx.callSign.trim().isEmpty ? 'NOCS' : ctx.callSign.trim();
      _base = FlightLog(
        id: '$cs-${_stamp(z)}',
        updatedAt: nowUtc,
        callSign: ctx.callSign,
        registration: ctx.registration,
        plannedDep: ctx.plannedDep,
        plannedArr: ctx.plannedArr,
        alternate: ctx.alternate,
        planSource: ctx.planSource,
        blockOut: z,
        plannedTimeH: ctx.plannedTimeH,
        plannedTripKg: ctx.plannedTripKg,
        cruiseFl: ctx.cruiseFl,
        fuelBlockOutKg: fuelKg(t),
        finalReserveKg: ctx.finalReserveKg,
        zfwKg: ctx.zfwKg,
      );
      _track.add(_point(t, z));
      _lastSample = nowUtc;
      _prevAlerts = ctx.alertTexts.toSet();
      return TrackerEvent.blockOut;
    }

    // Stats from block-out to block-in.
    final alertsNow = ctx.alertTexts.toSet();
    for (final a in alertsNow.difference(_prevAlerts)) {
      _alerts[a] = (_alerts[a] ?? 0) + 1;
    }
    _prevAlerts = alertsNow;
    if (t.mach > _maxMach) _maxMach = t.mach;
    if (t.altitude > _maxAlt) _maxAlt = t.altitude;
    if (t.mach >= 1) _ssSec += dt;
    if (t.reheatActive.any((r) => r)) _rhSec += dt;
    if (!t.onGround) _dist += t.gs * dt / 3600;
    if (running && nowUtc.difference(_lastSample!) >= _sampleEvery) {
      _track.add(_point(t, z));
      _lastSample = nowUtc;
    }

    switch (phase) {
      case TrackerPhase.taxiOut:
        if (!running && t.onGround) {
          _reset();
          return TrackerEvent.discarded;
        }
        if (wasOnGround && !t.onGround && t.ias > 80) {
          phase = TrackerPhase.airborne;
          _patch({
            'takeoff': z,
            'fuelTakeoffKg': fuelKg(t),
            'actualDep': ctx.nearestAirport(t.latitude, t.longitude),
          });
          _track.add(_point(t, z));
          return TrackerEvent.takeoff;
        }
      case TrackerPhase.airborne:
        if (!t.onGround) {
          _lastAir = t;
          break;
        }
        final a = _lastAir ?? t;
        phase = TrackerPhase.landed;
        _touchdownNow = nowUtc;
        _airborneSince = null;
        _patch({
          'touchdown': z,
          'fuelLandingKg': fuelKg(t),
          'actualArr': ctx.nearestAirport(t.latitude, t.longitude),
          'touchdownFpm': (t.isLanding ? t.touchdownVS : a.vs).abs(),
          'touchdownG': t.isLanding ? t.touchdownGForce : a.gForce,
          'touchdownPitch': t.isLanding ? t.touchdownPitch : a.pitch,
          'touchdownIas': a.ias,
          'bounces': 0,
        });
        _track.add(_point(t, z));
        return TrackerEvent.touchdown;
      case TrackerPhase.landed:
        if (!t.onGround) {
          _stoppedSince = null;
          _airborneSince ??= nowUtc;
          if (nowUtc.difference(_airborneSince!) > _goAroundAfter) {
            phase = TrackerPhase.airborne;
            _airborneSince = _touchdownNow = null;
            _patch({
              for (final k in [
                'touchdown',
                'fuelLandingKg',
                'actualArr',
                'touchdownFpm',
                'touchdownG',
                'touchdownPitch',
                'touchdownIas',
              ])
                k: null,
              'bounces': 0,
            });
            return TrackerEvent.goAround;
          }
          break;
        }
        // Back on the ground: a re-contact shortly after touchdown is a bounce.
        if (_airborneSince != null &&
            nowUtc.difference(_touchdownNow!) <= _bounceWindow) {
          _patch({'bounces': _base!.bounces + 1});
        }
        _airborneSince = null;
        if (running) {
          _stoppedSince = null;
        } else {
          _stoppedSince ??= nowUtc;
          if (nowUtc.difference(_stoppedSince!) >= _shutdownFor) {
            phase = TrackerPhase.done;
            _patch({'blockIn': z, 'fuelBlockInKg': fuelKg(t)});
            return TrackerEvent.blockIn;
          }
        }
      default:
        break;
    }
    return null;
  }
}
