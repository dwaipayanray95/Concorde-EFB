import '../../../../core/concorde_fuel_schematic.dart';
import '../models/telemetry_model.dart';
import '../models/flight_log_entry.dart';

/// Detects takeoff/landing from live telemetry and auto-builds a
/// [FlightLogEntry] the instant a landing is detected -- no manual
/// record/stop button, no per-frame storage. Pure Dart (no Riverpod/Flutter
/// deps) so it's independently unit-testable; the caller supplies an
/// airport-lookup closure and feeds it every telemetry frame as it arrives.
class FlightLogTracker {
  /// Concorde's published VR floor (see ConcordeLogic.computeTakeoffSpeeds)
  /// is 170 kt -- below that, wheels haven't left the ground regardless of
  /// pitch/VS noise.
  static const double takeoffMinIasKt = 170;

  /// A small positive floor (not exactly >0) so ground roll pitch/VS jitter
  /// can't false-trigger a takeoff while still stationary/taxiing.
  static const double takeoffMinVsFpm = 200;

  /// Safety valve: if a takeoff is ever mis-detected (e.g. a rejected
  /// takeoff roll briefly clearing the IAS/VS floor from a bump) and no
  /// real landing ever follows, the tracker would otherwise latch airborne
  /// forever and silently stop logging any further flights. No real
  /// Concorde flight (including diversions) runs anywhere near this long.
  static const Duration maxFlightDuration = Duration(hours: 6);

  final String Function(double lat, double lon) nearestAirportIcao;

  FlightLogTracker({required this.nearestAirportIcao});

  bool _airborne = false;
  bool get isAirborne => _airborne;

  /// True only when we actually witnessed the climb-out (IAS/VS thresholds
  /// met at the moment ground contact was lost) -- false when we merely
  /// noticed we were already flying (app/bridge connected mid-flight, or
  /// reconnected after a drop). Landings are captured either way; this
  /// just decides whether a real departure airport/time can be attributed.
  bool _hasConfirmedLiftoff = false;

  DateTime? _liftoffTime;
  double? _liftoffLat;
  double? _liftoffLon;
  double _liftoffFuelKg = 0;

  DateTime? _lastFrameTime;
  bool _wasLanding = false;

  double _distanceNm = 0;
  double _maxMach = 0;
  double _maxAltitudeFt = 0;
  double _reheatSeconds = 0;

  /// Feed one telemetry frame -- call on every frame the bridge delivers,
  /// not just UI-throttled updates, so distance/reheat-time integration and
  /// the takeoff/landing edges aren't missed or double-counted. Returns a
  /// completed [FlightLogEntry] exactly once, the moment a landing is
  /// detected; null on every other call (including while on the ground).
  FlightLogEntry? ingest(TelemetryModel frame, DateTime now) {
    final fuelKg = ConcordeFuelSchematic.totalFuelKg(
      ConcordeFuelSchematic.computeTankFills(frame),
    );

    if (!_airborne) {
      // Ground-contact truth alone is enough to start tracking -- a
      // rejected takeoff roll can't false-trigger this (SIM_ON_GROUND
      // stays true throughout a bump; wheels never actually left), but
      // genuinely being airborne with no known liftoff (app/bridge
      // connected mid-flight) must still be tracked so the eventual
      // landing is never silently missed. The IAS/VS climb signal is only
      // used to decide whether we can trust this as a *real* liftoff
      // (departure airport/time); otherwise those are left blank rather
      // than attributed to wherever we happened to start observing.
      if (!frame.onGround) {
        _airborne = true;
        _hasConfirmedLiftoff =
            frame.ias > takeoffMinIasKt && frame.vs > takeoffMinVsFpm;
        _liftoffTime = now;
        _liftoffLat = frame.latitude;
        _liftoffLon = frame.longitude;
        _liftoffFuelKg = fuelKg;
        _lastFrameTime = now;
        _distanceNm = 0;
        _maxMach = frame.mach;
        _maxAltitudeFt = frame.altitude;
        _reheatSeconds = 0;
        _wasLanding = false;
      }
      return null;
    }

    if (now.difference(_liftoffTime!) > maxFlightDuration) {
      // Stuck in a false "airborne" latch (see maxFlightDuration) -- abandon
      // this tracking attempt without saving a bogus multi-hour entry, and
      // drop back to ground state so a real takeoff can be detected again.
      _airborne = false;
      return null;
    }

    // Airborne: integrate ground-track distance from ground speed x time
    // (cheaper and more numerically stable than summing lat/lon deltas at
    // ~25 Hz, where haversine's small-angle precision loss would otherwise
    // accumulate over hundreds of thousands of additions) and reheat time
    // between consecutive frames, and track flight maxima.
    if (_lastFrameTime != null) {
      final dtHours =
          now.difference(_lastFrameTime!).inMilliseconds / 3600000.0;
      _distanceNm += frame.gs * dtHours;
      if (frame.reheatActive.any((r) => r)) {
        _reheatSeconds += dtHours * 3600.0;
      }
    }
    _lastFrameTime = now;
    if (frame.mach > _maxMach) _maxMach = frame.mach;
    if (frame.altitude > _maxAltitudeFt) _maxAltitudeFt = frame.altitude;

    // Edge-detect the isLanding pulse so a flight is only ever saved once,
    // on the first frame it flips true (the bridge latches it true for a
    // few seconds after touchdown).
    final isFirstLandingFrame = frame.isLanding && !_wasLanding;
    _wasLanding = frame.isLanding;
    if (!isFirstLandingFrame) return null;

    final entry = FlightLogEntry(
      id: 'flight_${_liftoffTime!.millisecondsSinceEpoch}',
      date: _liftoffTime!.toLocal().toString().substring(0, 19),
      durationSeconds: now.difference(_liftoffTime!).inSeconds,
      // Only attribute a departure airport when we actually witnessed the
      // climb-out -- otherwise "_liftoffLat/_liftoffLon" is just wherever
      // we first noticed we were already flying, not a real departure.
      departureIcao: _hasConfirmedLiftoff
          ? nearestAirportIcao(_liftoffLat!, _liftoffLon!)
          : '',
      arrivalIcao: nearestAirportIcao(frame.latitude, frame.longitude),
      distanceNm: _distanceNm,
      maxMach: _maxMach > 0 ? _maxMach : null,
      maxAltitudeFt: _maxAltitudeFt > 0 ? _maxAltitudeFt : null,
      fuelBurnedKg: _liftoffFuelKg > fuelKg ? _liftoffFuelKg - fuelKg : 0,
      reheatSeconds: _reheatSeconds.round(),
      touchdownVS: frame.touchdownVS,
      touchdownPitch: frame.touchdownPitch,
      touchdownGForce: frame.touchdownGForce,
    );

    _airborne = false;
    return entry;
  }
}
