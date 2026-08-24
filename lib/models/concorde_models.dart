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
  });
}

class BlockFuelInputs {
  final double tripKg;
  final double? taxiKg;
  final double? contingencyPct;
  final double? finalReserveKg;
  final double? alternateNm;
  final double? burnKgPerNm;

  const BlockFuelInputs({
    required this.tripKg,
    this.taxiKg,
    this.contingencyPct,
    this.finalReserveKg,
    this.alternateNm,
    this.burnKgPerNm,
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

class RunwayEnvironmentInputs {
  final double? runwayElevFt;
  final MetarQnh? qnh;
  final double? oatC;
  final double? headwindKt;
  final double? crosswindKt;

  const RunwayEnvironmentInputs({
    this.runwayElevFt,
    this.qnh,
    this.oatC,
    this.headwindKt,
    this.crosswindKt,
  });
}

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
  });
}
