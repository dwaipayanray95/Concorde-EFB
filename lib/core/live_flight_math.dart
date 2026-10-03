import 'dart:math' as math;
import 'concorde_constants.dart';
import 'concorde_logic.dart';

/// Indicative Concorde CG corridor (% MAC) vs Mach. The corridor moves aft
/// as the centre of lift moves aft going supersonic -- which is why fuel is
/// pumped to the aft trim tank during the acceleration and forward again in
/// the deceleration. Approximation of the published envelope (~53.5 % for
/// takeoff, ~59 % at Mach 2); verify against the DC Designs manual.
class CgLimits {
  final double fwd;
  final double aft;
  const CgLimits(this.fwd, this.aft);
}

const _cgTable = <(double, double, double)>[
  // mach, fwd, aft
  (0.0, 51.5, 54.5),
  (0.9, 52.5, 55.5),
  (1.2, 54.5, 57.5),
  (1.6, 56.0, 58.5),
  (2.0, 57.0, 59.5),
  (2.2, 57.0, 59.5),
];

CgLimits cgLimitsForMach(double mach) {
  final m = mach.clamp(0.0, 2.2);
  for (var i = 1; i < _cgTable.length; i++) {
    final (m0, f0, a0) = _cgTable[i - 1];
    final (m1, f1, a1) = _cgTable[i];
    if (m <= m1) {
      final x = (m - m0) / (m1 - m0);
      return CgLimits(f0 + (f1 - f0) * x, a0 + (a1 - a0) * x);
    }
  }
  return const CgLimits(57.0, 59.5);
}

/// Live navigation/fuel prediction toward the destination.
class LiveFlightPrediction {
  /// Great-circle distance to the destination (nm).
  final double distToDestNm;

  /// Distance from the aircraft to the top of descent (nm); negative when
  /// past it.
  final double distToTodNm;

  /// Remaining flight time (h) at current ground speed + descent profile.
  final double timeToDestH;

  /// Fuel predicted on landing (kg).
  final double fuelAtDestKg;

  const LiveFlightPrediction({
    required this.distToDestNm,
    required this.distToTodNm,
    required this.timeToDestH,
    required this.fuelAtDestKg,
  });
}

/// Predicts TOD and landing fuel from live state. The remaining distance
/// is split into "cruise until TOD" flown at the current ground speed and
/// smoothed fuel flow, plus the descent segment from the current altitude
/// using the same descent model as the planner (3 nm / 1,000 ft + 30 nm,
/// descent fuel flow).
LiveFlightPrediction predictToDestination({
  required double lat,
  required double lon,
  required double destLat,
  required double destLon,
  required double altitudeFt,
  required double groundSpeedKt,
  required double fuelFlowKgH,
  required double fuelOnBoardKg,
}) {
  final dist = ConcordeLogic.greatCircleNM(lat, lon, destLat, destLon);
  final descent = ConcordeLogic.estimateDescent(altitudeFt);
  final toTod = dist - descent.distNm;
  final gs = math.max(groundSpeedKt, 150.0);

  double timeH;
  double burnKg;
  if (toTod > 0) {
    final cruiseH = toTod / gs;
    timeH = cruiseH + descent.timeH;
    burnKg =
        cruiseH * fuelFlowKgH +
        descent.timeH * ConcordeConstants.fuel.descentFuelFlowKgH;
  } else {
    // Already descending: scale the descent segment to what's left.
    final frac = descent.distNm > 0
        ? (dist / descent.distNm).clamp(0.0, 1.0)
        : 0.0;
    timeH = descent.timeH * frac;
    burnKg = timeH * ConcordeConstants.fuel.descentFuelFlowKgH;
  }
  return LiveFlightPrediction(
    distToDestNm: dist,
    distToTodNm: toTod,
    timeToDestH: timeH,
    fuelAtDestKg: fuelOnBoardKg - burnKg,
  );
}
