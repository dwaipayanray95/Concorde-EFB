import 'dart:math' as math;
import 'concorde_constants.dart';
import 'concorde_logic.dart';

/// Concorde CG corridor (% MAC) vs Mach, digitised from the CG chart in
/// the DC Designs Concorde manual (p.78, "ideal CoG setting against Mach").
/// The corridor moves aft going supersonic (centre of lift moves aft), so
/// fuel is pumped aft to the trim tank in the acceleration and forward
/// again in the deceleration.
class CgLimits {
  final double fwd;
  final double aft;
  const CgLimits(this.fwd, this.aft);
}

double _interp(List<(double, double)> table, double x) {
  if (x <= table.first.$1) return table.first.$2;
  for (var i = 1; i < table.length; i++) {
    final (x0, y0) = table[i - 1];
    final (x1, y1) = table[i];
    if (x <= x1) return y0 + (y1 - y0) * (x - x0) / (x1 - x0);
  }
  return table.last.$2;
}

// (mach, % MAC) -- DC Designs manual CG chart.
/// Takeoff CG (owner, per the DC Designs procedures): 56 % is set for
/// takeoff and held until the Mach corridor applies above 10,000 ft.
const takeoffCgTargetPct = 56.0;

/// Below this height above the departure field the CG card shows the
/// takeoff target and the CG limit alerts stay off.
const cgCorridorArmFt = 10000.0;

const _cgFwdLimit = <(double, double)>[
  (0.0, 51.3),
  (0.82, 51.3),
  (0.95, 53.0),
  (1.13, 54.4),
  (1.5, 55.9),
  (2.05, 56.6),
];
const _cgAftLimit = <(double, double)>[
  (0.0, 53.7),
  (0.2, 53.7),
  (0.5, 54.0),
  (0.95, 56.9),
  (1.63, 59.2),
  (2.2, 59.2),
];
// Ideal CG (red line on the chart): ~53.5 % subsonic (manual text: 54 %
// for takeoff and landing), 55 % at M0.95, 59 % at Mach 2.
const _cgIdeal = <(double, double)>[
  (0.0, 53.5),
  (0.75, 53.5),
  (0.95, 55.0),
  (2.0, 59.0),
];

CgLimits cgLimitsForMach(double mach) {
  final m = mach.clamp(0.0, 2.2);
  return CgLimits(_interp(_cgFwdLimit, m), _interp(_cgAftLimit, m));
}

/// The manual's ideal CG for this Mach, kept inside the corridor.
double cgTargetForMach(double mach) {
  final lim = cgLimitsForMach(mach);
  return _interp(
    _cgIdeal,
    mach.clamp(0.0, 2.2),
  ).clamp(lim.fwd + 0.2, lim.aft - 0.2).toDouble();
}

/// Live navigation/fuel prediction toward the destination.
class LiveFlightPrediction {
  /// Distance still to fly to the destination along the route (nm).
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

/// Predicts TOD and landing fuel from live state. [distToDestNm] is the
/// distance still to fly along the route (see [RouteMath]). It is split
/// into "cruise until TOD" flown at the current ground speed and
/// smoothed fuel flow, plus the descent segment from the current altitude
/// using the same descent model as the planner (3 nm / 1,000 ft + 30 nm,
/// descent fuel flow).
LiveFlightPrediction predictToDestination({
  required double distToDestNm,
  required double altitudeFt,
  required double groundSpeedKt,
  required double fuelFlowKgH,
  required double fuelOnBoardKg,
}) {
  final dist = math.max(distToDestNm, 0.0);
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
