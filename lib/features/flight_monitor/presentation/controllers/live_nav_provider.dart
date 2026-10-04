import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/concorde_logic.dart';
import '../../../../core/concorde_fuel_schematic.dart';
import '../../../../core/live_flight_math.dart';
import '../../../../core/route_math.dart';
import '../../../../models/concorde_models.dart';
import '../../../../providers/efb_providers.dart';
import 'telemetry_provider.dart';

/// Everything the Flight Monitor derives from live telemetry + the plan,
/// computed once and shared (MFD strip, progress bar, ...).
class LiveNav {
  final FlightBurnPhase phase;

  /// Fuel flow used for predictions: smoothed sim value, or the phase model
  /// before any real flow is seen.
  final double fuelFlowKgH;
  final double fuelOnBoardKg;

  /// Planned route length (nm) -- the whole trip.
  final double routeNm;

  /// Prediction to destination, null without a destination / live data.
  final LiveFlightPrediction? prediction;

  const LiveNav({
    required this.phase,
    required this.fuelFlowKgH,
    required this.fuelOnBoardKg,
    required this.routeNm,
    required this.prediction,
  });

  /// 0..1 progress along the route.
  double get progress {
    final p = prediction;
    if (p == null || routeNm <= 0) return 0;
    return (1 - p.distToDestNm / routeNm).clamp(0.0, 1.0);
  }

  /// 0..1 position of the top of descent along the route.
  double? get todProgress {
    final p = prediction;
    if (p == null || routeNm <= 0) return null;
    final flownNm = routeNm - p.distToDestNm;
    return ((flownNm + p.distToTodNm) / routeNm).clamp(0.0, 1.0);
  }
}

final liveNavProvider = Provider<LiveNav?>((ref) {
  final monitor = ref.watch(flightMonitorProvider);
  final t = monitor.currentTelemetry;
  if (t == null || !t.flightLoaded) return null;

  final phase = ConcordeLogic.classifyBurnPhase(
    altitudeFt: t.heightAboveGround(
      fieldElevationFt: ref.watch(depAirportProvider)?.elevationFt,
    ),
    vsFpm: t.vs,
    reheatActive: t.reheatActive,
    onGround: t.onGround,
  );
  final smoothed = monitor.smoothedFuelFlowKgH ?? 0;
  final flow = smoothed >= 500
      ? smoothed
      : ConcordeLogic.phaseFuelFlowKgH(phase, t.altitude / 100);
  // Fuel-at-destination uses the burn rate for the rest of the trip. During
  // takeoff/climb/reheat acceleration the actual flow (up to ~60 t/h) is
  // far above the cruise burn, so extrapolating it over the whole remaining
  // distance falsely predicts running dry -- use the planned cruise flow
  // until the aircraft is actually cruising.
  final cruising =
      phase == FlightBurnPhase.cruise || phase == FlightBurnPhase.descent;
  final predictionFlow = cruising
      ? flow
      : ConcordeLogic.phaseFuelFlowKgH(
          FlightBurnPhase.cruise,
          ref.watch(cruiseFLProvider),
        );
  final fob = ConcordeFuelSchematic.totalFuelKg(
    ConcordeFuelSchematic.computeTankFills(t),
  );

  final dest = ref.watch(arrAirportProvider);
  LiveFlightPrediction? prediction;
  if (dest != null) {
    // Distance still to fly along the planned route, or the great circle
    // scaled by this plan's route/great-circle ratio when no fixes exist.
    final polyline = ref.watch(routePolylineProvider);
    // The fix-by-fix polyline is usually shorter than the planned route
    // distance (SimBrief's includes SID/STAR turns and the navlog skips
    // procedure legs), so scale it to the planned distance -- otherwise the
    // aircraft looks well en route while still at the gate.
    final planned = ref.watch(plannedDistanceProvider);
    final polylineNm = polyline != null ? RouteMath.polylineNm(polyline) : 0.0;
    final polyScale = polylineNm > 1 && planned > 0
        ? planned / polylineNm
        : 1.0;
    final dist = polyline != null
        ? RouteMath.remainingAlongRouteNm(t.latitude, t.longitude, polyline) *
              polyScale
        : ConcordeLogic.greatCircleNM(
                t.latitude,
                t.longitude,
                dest.lat,
                dest.lon,
              ) *
              ref.watch(routeFactorProvider);
    prediction = predictToDestination(
      distToDestNm: dist,
      // Descent distance is from the aircraft down to the destination
      // airport, not to sea level.
      altitudeFt: t.heightAboveGround(fieldElevationFt: dest.elevationFt),
      groundSpeedKt: t.gs,
      fuelFlowKgH: predictionFlow,
      fuelOnBoardKg: fob,
    );
  }

  return LiveNav(
    phase: phase,
    fuelFlowKgH: flow,
    fuelOnBoardKg: fob,
    routeNm: ref.watch(plannedDistanceProvider),
    prediction: prediction,
  );
});
