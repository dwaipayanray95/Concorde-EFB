/// The aircraft's current fuel-burn phase, classified live from telemetry
/// (see [ConcordeLogic.classifyBurnPhase]) so the Flight Monitor's
/// estimated-air-time readout can use the real hourly fuel flow for
/// whatever the aircraft is actually doing right now.
enum FlightBurnPhase { ground, climb, reheatAccel, cruise, descent }

class ProfileSegment {
  final double timeH;
  final double distNm;

  const ProfileSegment({required this.timeH, required this.distNm});
}

class CruiseClimbSegment {
  final int fl;
  final double distNm;
  final double timeH;
  final double burnKg;
  final double burnKgPerNm;
  final double tasKt;

  const CruiseClimbSegment({
    required this.fl,
    required this.distNm,
    required this.timeH,
    required this.burnKg,
    required this.burnKgPerNm,
    required this.tasKt,
  });
}

class CruiseMissionProfile {
  final ProfileSegment climb;
  final ProfileSegment accel;
  final ProfileSegment cruise;
  final ProfileSegment descent;
  final List<CruiseClimbSegment> cruiseSegments;
  final double climbKg;
  final double accelKg;
  final double cruiseKg;
  final double descentKg;
  final double tripKg;
  final double totalTimeH;
  final double avgCruiseBurnKgPerNm;
  final double avgCruiseTasKt;
  final int initialCruiseFl;
  final int targetCruiseFl;

  /// The FL the pilot selected. [targetCruiseFl] can be lower when the
  /// sector is too short to climb that high (see [flCappedForDistance]).
  final int selectedCruiseFl;

  /// True when the profile includes the transonic acceleration and Mach 2
  /// cruise; false for a subsonic (M0.95) profile.
  final bool supersonic;

  /// True when the selected FL (or supersonic cruise) wasn't reachable in
  /// the planned distance and the profile was flown lower/subsonic.
  final bool flCappedForDistance;

  const CruiseMissionProfile({
    required this.climb,
    required this.accel,
    required this.cruise,
    required this.descent,
    required this.cruiseSegments,
    required this.climbKg,
    required this.accelKg,
    required this.cruiseKg,
    required this.descentKg,
    required this.tripKg,
    required this.totalTimeH,
    required this.avgCruiseBurnKgPerNm,
    required this.avgCruiseTasKt,
    required this.initialCruiseFl,
    required this.targetCruiseFl,
    required this.selectedCruiseFl,
    required this.supersonic,
    required this.flCappedForDistance,
  });
}

class BlockFuelInputs {
  final double tripKg;
  final double? taxiKg;
  final double? contingencyPct;
  final double? finalReserveKg;
  final double? alternateNm;

  const BlockFuelInputs({
    required this.tripKg,
    this.taxiKg,
    this.contingencyPct,
    this.finalReserveKg,
    this.alternateNm,
  });
}

class BlockFuelBreakdown {
  final double tripKg;
  final double taxiKg;
  final double contingencyKg;
  final double finalReserveKg;
  final double alternateKg;
  final double blockKg;

  const BlockFuelBreakdown({
    required this.tripKg,
    required this.taxiKg,
    required this.contingencyKg,
    required this.finalReserveKg,
    required this.alternateKg,
    required this.blockKg,
  });
}

/// Runway surface state. Drives the wet/contaminated distance factors and
/// the V1 reduction.
enum RunwayCondition { dry, wet, contaminated }

/// What the pilot picked in the runway-condition selector; [auto] derives
/// the condition from the METAR present/recent weather.
enum RunwayConditionMode { auto, dry, wet, contaminated }

class RunwayEnvironmentInputs {
  final double? runwayElevFt;
  final MetarQnh? qnh;
  final double? oatC;

  /// Steady headwind component (negative = tailwind). Null when the METAR
  /// has no usable wind (missing METAR, or calm/unparseable).
  final double? headwindKt;

  /// Crosswind component, gust-inclusive (the conservative figure that is
  /// checked against the crosswind limit). Null when wind is unknown.
  final double? crosswindKt;

  /// Tailwind component used against the tailwind limit, gust-inclusive
  /// (0 when the wind is a headwind). Null when wind is unknown.
  final double? tailwindKt;

  /// Gust increment above the steady wind (kt), 0 when no gust reported.
  final double gustIncrementKt;

  final RunwayCondition condition;

  /// False when there was no METAR / no parseable wind group -- the UI
  /// must say so instead of silently treating the wind as calm.
  final bool windDataAvailable;

  const RunwayEnvironmentInputs({
    this.runwayElevFt,
    this.qnh,
    this.oatC,
    this.headwindKt,
    this.crosswindKt,
    this.tailwindKt,
    this.gustIncrementKt = 0,
    this.condition = RunwayCondition.dry,
    this.windDataAvailable = true,
  });
}

/// Aircraft weights for the current plan (kg).
class WeightSummary {
  final double zfw;

  /// Fuel actually on board (planned fuel capped at tank capacity).
  final double fuelOnBoard;

  /// Fuel the plan asks for (block + extra), may exceed capacity.
  final double plannedFuel;

  /// Ramp/taxi weight -- includes taxi fuel.
  final double ramp;

  /// Start-of-takeoff weight (ramp minus taxi fuel).
  final double tow;

  /// Landing weight (takeoff weight minus trip fuel).
  final double lw;
  final double pax;

  const WeightSummary({
    required this.zfw,
    required this.fuelOnBoard,
    required this.plannedFuel,
    required this.ramp,
    required this.tow,
    required this.lw,
    required this.pax,
  });

  bool get overCapacity => plannedFuel > fuelOnBoard;
}

class TakeoffSpeeds {
  final double v1;
  final double vr;
  final double v2;
  const TakeoffSpeeds({required this.v1, required this.vr, required this.v2});
}

class LandingSpeeds {
  /// Reference landing speed at the threshold.
  final double vref;

  /// Approach speed: VREF + wind/gust additive.
  final double vapp;
  const LandingSpeeds({required this.vref, required this.vapp});
}

/// Fuel endurance vs requirement, both burned at realistic rates: trip
/// fuel over the planned ETE, everything beyond it at holding fuel flow.
class FuelEndurance {
  final double airborneFuelKg;
  final double enduranceH;
  final double requiredH;
  const FuelEndurance({
    required this.airborneFuelKg,
    required this.enduranceH,
    required this.requiredH,
  });
  bool get sufficient => enduranceH + 1e-9 >= requiredH;
}

enum AlternateStatus { ok, missing, unknownAirport, sameAsArrival, tooFar }

class MetarQnh {
  final String unit; // "hPa" or "inHg"
  final double value;

  const MetarQnh({required this.unit, required this.value});
}

class RunwayFeasibility {
  final double baseRequiredLengthMEst;
  final double requiredLengthMEst;
  final double runwayLengthM;
  final bool feasible;
  final double correctionFactor;
  final Map<String, double> correctionBreakdownPct;
  final Map<String, dynamic> correctionInputs;

  /// Independent hard limits from the BA Concorde Flying Manual Vol II
  /// (Operating Limitations, 01.01.02) -- each defaults to true (not
  /// violated) when the underlying data isn't available, so a runway
  /// missing width data in the offline airport DB doesn't get flagged as
  /// infeasible on absence of evidence.
  final bool widthOk;
  final bool altitudeOk;
  final bool crosswindOk;

  /// Tailwind within the 10 kt limit (true when wind is unknown).
  final bool tailwindOk;

  /// False when no wind data was available for this check.
  final bool windDataAvailable;
  final RunwayCondition condition;

  const RunwayFeasibility({
    required this.baseRequiredLengthMEst,
    required this.requiredLengthMEst,
    required this.runwayLengthM,
    required this.feasible,
    required this.correctionFactor,
    required this.correctionBreakdownPct,
    required this.correctionInputs,
    this.widthOk = true,
    this.altitudeOk = true,
    this.crosswindOk = true,
    this.tailwindOk = true,
    this.windDataAvailable = true,
    this.condition = RunwayCondition.dry,
  });
}
