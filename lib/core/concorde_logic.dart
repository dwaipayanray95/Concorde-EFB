import 'dart:math' as math;
import '../models/concorde_models.dart';
import 'concorde_constants.dart';

class ConcordeLogic {
  static double toRad(double deg) => (deg * math.pi) / 180;
  static double nmFromKm(double km) => km * 0.539957;

  static double greatCircleNM(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const rKm = 6371.0088;
    final phi1 = toRad(lat1);
    final phi2 = toRad(lat2);
    final dphi = toRad(lat2 - lat1);
    final dlambda = toRad(lon2 - lon1);
    final a =
        math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(phi1) *
            math.cos(phi2) *
            math.sin(dlambda / 2) *
            math.sin(dlambda / 2);
    return nmFromKm(2 * rKm * math.asin(math.sqrt(a)));
  }

  static double initialBearingDeg(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final phi1 = toRad(lat1);
    final phi2 = toRad(lat2);
    final dlambda = toRad(lon2 - lon1);
    final y = math.sin(dlambda) * math.cos(phi2);
    final x =
        math.cos(phi1) * math.sin(phi2) -
        math.sin(phi1) * math.cos(phi2) * math.cos(dlambda);
    final theta = math.atan2(y, x);
    final deg = (theta * 180) / math.pi;
    return deg >= 0 ? deg % 360 : (deg % 360) + 360;
  }

  static String inferDirectionEW(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final brg = initialBearingDeg(lat1, lon1, lat2, lon2);
    return brg < 180 ? 'E' : 'W';
  }

  static List<int> nonRvsmValidFLs(String direction) {
    final start = direction == 'E' ? 410 : 430;
    final levels = <int>[];
    for (int fl = start; fl <= 590; fl += 40) {
      levels.add(fl);
    }
    return levels;
  }

  static double snapToNonRvsm(double fl, String? direction) {
    if (fl < 410) return fl;

    List<int> validLevels;
    if (direction != null) {
      validLevels = nonRvsmValidFLs(direction);
    } else {
      validLevels = [...nonRvsmValidFLs('E'), ...nonRvsmValidFLs('W')];
      validLevels.sort();
    }

    int best = validLevels[0];
    double bestDiff = (best - fl).abs();

    for (final v in validLevels) {
      final d = (v - fl).abs();
      if (d < bestDiff || (d == bestDiff && v < best)) {
        best = v;
        bestDiff = d;
      }
    }

    return best.toDouble();
  }

  static double clampCruiseFL(double input) {
    return input.clamp(0, 590).toDouble();
  }

  /// Steady-state Mach 2 supercruise fuel flow (4 engines, kg/h) at a given
  /// FL. Tapers from ~20,500 kg/h at the lowest usable cruise level (heavier
  /// aircraft, more drag) down to ~17,000 kg/h at FL600 (lightest, final
  /// cruise-climb step) -- see [ConcordeConstants.fuel] for sourcing.
  static double cruiseFuelFlowKgHAtFL(double fl) {
    final clamped = fl.clamp(410, 600).toDouble();
    final x = (clamped - 410) / (600 - 410);
    final hi = ConcordeConstants.fuel.cruiseFuelFlowKgHAtFl500;
    final lo = ConcordeConstants.fuel.cruiseFuelFlowKgHAtFl600;
    return hi - (hi - lo) * x;
  }

  static double cruiseTimeHours(double distanceNM, {double? tasKT}) {
    final speed = tasKT ?? ConcordeConstants.speeds.cruiseTasKt;
    if (speed <= 0) throw Exception("TAS must be positive");
    return distanceNM / speed;
  }

  static ProfileSegment estimateClimb(
    double cruiseAltFt, {
    double avgFpm = 2500,
    double avgGSkt = 450,
  }) {
    final tH = math.max(cruiseAltFt, 0.0) / math.max(avgFpm, 100.0) / 60.0;
    final dNM = tH * math.max(avgGSkt, 200.0);
    return ProfileSegment(timeH: tH, distNm: dNM);
  }

  static ProfileSegment estimateDescent(
    double cruiseAltFt, {
    double avgGSkt = 420,
    double bufferNM = 30,
  }) {
    final dRule = math.max(cruiseAltFt, 0.0) / 300.0;
    final dist = dRule + bufferNM;
    final tH = dist / math.max(avgGSkt, 200.0);
    return ProfileSegment(timeH: tH, distNm: dist);
  }

  static const double cruiseClimbStepFl = 20;
  static const double cruiseClimbStartFl = 500;
  static const double suprAccelNm = 90;
  static const double suprAccelTimeH = 12 / 60;

  static double cruiseTasKtForFL(double fl) {
    final clamped = clampCruiseFL(fl);
    if (clamped < 500) {
      final x = ((clamped - 250) / 250).clamp(0.0, 1.0);
      return 520 + 340 * x;
    }
    final x = ((clamped - 500) / 90).clamp(0.0, 1.0);
    return 1135 + 55 * x;
  }

  static List<int> buildCruiseClimbLevels(double initialFL, double targetFL) {
    final start = clampCruiseFL(initialFL).toInt();
    final end = clampCruiseFL(targetFL).toInt();
    if (end <= start) return [end];

    final levels = <int>[];
    for (var fl = start; fl <= end; fl += cruiseClimbStepFl.toInt()) {
      levels.add(fl);
    }
    if (levels.last != end) levels.add(end);
    return levels;
  }

  static CruiseMissionProfile buildCruiseMissionProfile(
    double plannedDistanceNM,
    double selectedCruiseFL,
  ) {
    final distanceNM = math.max(plannedDistanceNM, 0.0);
    final targetFL = clampCruiseFL(selectedCruiseFL);
    final initialCruiseFL = targetFL >= cruiseClimbStartFl
        ? cruiseClimbStartFl
        : targetFL;

    final climb = estimateClimb(initialCruiseFL * 100);
    final descent = estimateDescent(math.max(targetFL, initialCruiseFL) * 100);

    final coreRemainingNM = math.max(
      distanceNM - (climb.distNm + descent.distNm),
      0.0,
    );
    final useSupersonicAccel = targetFL >= cruiseClimbStartFl;
    final accelDistNM = useSupersonicAccel
        ? math.min(suprAccelNm, coreRemainingNM * 0.4)
        : 0.0;
    final accelTimeH = (useSupersonicAccel && suprAccelNm > 0)
        ? suprAccelTimeH * (accelDistNM / suprAccelNm)
        : 0.0;
    // Reheat/transonic-acceleration burn: real full-reheat fuel flow (4
    // engines) x the time actually spent in that burst, not a multiplier on
    // top of the cruise rate.
    final accelBurnKg = accelTimeH * ConcordeConstants.fuel.reheatFuelFlowKgH;

    final cruiseNM = math.max(coreRemainingNM - accelDistNM, 0.0);
    final cruiseLevels = buildCruiseClimbLevels(initialCruiseFL, targetFL);

    final weights = List.generate(cruiseLevels.length, (i) {
      if (cruiseLevels.length <= 1) return 1.0;
      final x = i / (cruiseLevels.length - 1);
      return 0.8 + 0.5 * x;
    });
    final weightSum = math.max(weights.fold(0.0, (s, w) => s + w), 1.0);

    final cruiseSegments = List.generate(cruiseLevels.length, (i) {
      final fl = cruiseLevels[i];
      final segmentNM = cruiseNM * (weights[i] / weightSum);
      final tasKT = math.max(cruiseTasKtForFL(fl.toDouble()), 1.0);
      final flowKgH = cruiseFuelFlowKgHAtFL(fl.toDouble());
      final timeH = segmentNM / tasKT;
      // Cruise burn is fundamentally a rate over TIME (fuel flow), not
      // distance -- matches the manual's own "fuel remaining / burn rate
      // per hour = endurance" method. burnKgPerNm below is a derived
      // display value only, not what drives the calculation.
      final burnKg = timeH * flowKgH;
      final burnKgPerNm = segmentNM > 0 ? burnKg / segmentNM : flowKgH / tasKT;
      return CruiseClimbSegment(
        fl: fl,
        distNm: segmentNM,
        timeH: timeH,
        burnKg: burnKg,
        burnKgPerNm: burnKgPerNm,
        tasKt: tasKT,
      );
    });

    final cruiseTimeH = cruiseSegments.fold(0.0, (s, seg) => s + seg.timeH);
    final cruiseKg = cruiseSegments.fold(0.0, (s, seg) => s + seg.burnKg);

    // Climb (subsonic/low-supersonic, pre-reheat-burst) and descent
    // (throttled back near idle) both driven by their own real fuel flow x
    // segment time -- see ConcordeConstants.fuel for sourcing.
    final climbKg = climb.timeH * ConcordeConstants.fuel.climbFuelFlowKgH;
    final descentKg = descent.timeH * ConcordeConstants.fuel.descentFuelFlowKgH;

    final avgCruiseBurnKgPerNm = cruiseNM > 0
        ? cruiseKg / cruiseNM
        : cruiseFuelFlowKgHAtFL(targetFL) /
              math.max(cruiseTasKtForFL(targetFL), 1.0);
    final avgCruiseTasKt = cruiseTimeH > 0
        ? cruiseNM / cruiseTimeH
        : cruiseTasKtForFL(targetFL);

    final tripKg = math.max(climbKg + accelBurnKg + cruiseKg + descentKg, 0.0);
    final totalTimeH = math.max(
      climb.timeH + accelTimeH + cruiseTimeH + descent.timeH,
      0.0,
    );

    return CruiseMissionProfile(
      climb: climb,
      accel: ProfileSegment(timeH: accelTimeH, distNm: accelDistNM),
      cruise: ProfileSegment(timeH: cruiseTimeH, distNm: cruiseNM),
      descent: descent,
      cruiseSegments: cruiseSegments,
      climbKg: climbKg,
      accelKg: accelBurnKg,
      cruiseKg: cruiseKg,
      descentKg: descentKg,
      tripKg: tripKg,
      totalTimeH: totalTimeH,
      avgCruiseBurnKgPerNm: avgCruiseBurnKgPerNm,
      avgCruiseTasKt: avgCruiseTasKt,
      initialCruiseFl: initialCruiseFL.toInt(),
      targetCruiseFl: targetFL.toInt(),
    );
  }

  static BlockFuelBreakdown blockFuelKg(BlockFuelInputs inputs) {
    final burn =
        inputs.burnKgPerNm ?? ConcordeConstants.fuel.alternateBurnKgPerNm;
    final altKg = math.max(inputs.alternateNm ?? 0.0, 0.0) * burn;
    final contKg =
        inputs.tripKg * math.max((inputs.contingencyPct ?? 0.0) / 100.0, 0.0);
    final total =
        inputs.tripKg +
        (inputs.taxiKg ?? 0.0) +
        contKg +
        (inputs.finalReserveKg ?? 0.0) +
        altKg;
    return BlockFuelBreakdown(
      tripKg: inputs.tripKg,
      taxiKg: inputs.taxiKg ?? 0.0,
      contingencyKg: contKg,
      finalReserveKg: inputs.finalReserveKg ?? 0.0,
      alternateKg: altKg,
      blockKg: total,
    );
  }

  /// Classifies the aircraft's current fuel-burn phase from live telemetry,
  /// so a live "estimated air time" readout can use the real hourly fuel
  /// flow for what the aircraft is actually doing right now (climbing,
  /// in reheat, level cruise, or descending) instead of one flat number.
  /// Reheat is read directly from the sim rather than inferred, since
  /// [TelemetryModel.reheatActive] is a genuine per-engine signal.
  static FlightBurnPhase classifyBurnPhase({
    required double altitudeFt,
    required double vsFpm,
    required List<bool> reheatActive,
  }) {
    if (altitudeFt < 1000) return FlightBurnPhase.ground;
    if (reheatActive.any((r) => r)) return FlightBurnPhase.reheatAccel;
    if (vsFpm > 300) return FlightBurnPhase.climb;
    if (vsFpm < -300) return FlightBurnPhase.descent;
    return FlightBurnPhase.cruise;
  }

  /// Real 4-engine fuel flow (kg/h) for the given phase, FL-sensitive for
  /// cruise (see [cruiseFuelFlowKgHAtFL]). Used to project "estimated air
  /// time" from current fuel + current phase/altitude, rather than naively
  /// dividing by whatever the instantaneous sim fuel-flow reading is (which
  /// is noisy/unrepresentative mid-climb or mid-reheat-burst).
  static double phaseFuelFlowKgH(FlightBurnPhase phase, double currentFL) {
    switch (phase) {
      case FlightBurnPhase.ground:
        return ConcordeConstants.fuel.idleFuelFlowKgH;
      case FlightBurnPhase.climb:
        return ConcordeConstants.fuel.climbFuelFlowKgH;
      case FlightBurnPhase.reheatAccel:
        return ConcordeConstants.fuel.reheatFuelFlowKgH;
      case FlightBurnPhase.descent:
        return ConcordeConstants.fuel.descentFuelFlowKgH;
      case FlightBurnPhase.cruise:
        return cruiseFuelFlowKgHAtFL(currentFL);
    }
  }

  static double weightScale(double actual, double reference) {
    if (actual <= 0 || reference <= 0) return 1.0;
    return math.sqrt(actual / reference);
  }

  static Map<String, double> computeTakeoffSpeeds(double towKg) {
    // Reference speeds (V1=180/VR=195/V2=220 kt) are assumed at this
    // reference weight. The manual quotes a V1 example of 170 kt but does
    // not state the weight it applies to, so this pairing is not directly
    // traceable to source — treat as an approximation pending real POH data.
    const refKg = 170000.0;
    final s = weightScale(towKg, refKg);
    final v1 = math.max(160.0, (180.0 * s).roundToDouble());
    final vr = math.max(170.0, (195.0 * s).roundToDouble());
    final v2 = math.max(190.0, (220.0 * s).roundToDouble());
    return {"V1": v1, "VR": vr, "V2": v2};
  }

  static Map<String, double> computeLandingSpeeds(double lwKg) {
    const refKg = 100000.0;
    final s = weightScale(lwKg, refKg);
    var vls = (175.0 * s).roundToDouble();
    if (vls < 170) vls = 170;
    var vapp = vls + 15;
    if (vapp < 185) vapp = 185;
    return {"VLS": vls, "VAPP": vapp};
  }

  static double? qnhToHpa(MetarQnh? qnh) {
    if (qnh == null) return null;
    if (qnh.unit == "hPa") return qnh.value;
    return qnh.value * 33.8638866667;
  }

  static double isaTempCAtElevationFt(double elevationFt) {
    return 15 - 1.98 * (elevationFt / 1000);
  }

  static Map<String, dynamic> runwayLengthCorrectionFactor(
    String phase,
    RunwayEnvironmentInputs? env,
  ) {
    final runwayElevFt = env?.runwayElevFt ?? 0.0;
    final qnhHpa = qnhToHpa(env?.qnh);
    final pressureAltFt = qnhHpa == null
        ? runwayElevFt
        : runwayElevFt + (1013.25 - qnhHpa) * 30;
    final isaTempC = isaTempCAtElevationFt(runwayElevFt);
    final oatC = env?.oatC;
    final headwindKt = env?.headwindKt;

    var pressurePctRaw = 0.0;
    pressurePctRaw = phase == "takeoff"
        ? (pressureAltFt / 1000) * 0.012
        : (pressureAltFt / 1000) * 0.007;
    final pressurePct = pressurePctRaw.clamp(-0.08, 0.35);

    final tempDelta = oatC == null ? null : oatC - isaTempC;
    var temperaturePct = 0.0;
    if (tempDelta != null) {
      if (phase == "takeoff") {
        temperaturePct = tempDelta >= 0 ? tempDelta * 0.01 : tempDelta * 0.004;
      } else {
        temperaturePct = tempDelta >= 0 ? tempDelta * 0.005 : tempDelta * 0.002;
      }
    }
    temperaturePct = temperaturePct.clamp(-0.1, 0.35);

    var windPct = 0.0;
    if (headwindKt != null) {
      if (headwindKt >= 0) {
        windPct = phase == "takeoff"
            ? -math.min(headwindKt * 0.01, 0.2)
            : -math.min(headwindKt * 0.01, 0.15);
      } else {
        final tailwind = headwindKt.abs();
        windPct = phase == "takeoff"
            ? math.min(tailwind * 0.03, 0.5)
            : math.min(tailwind * 0.04, 0.65);
      }
    }

    final totalPct = pressurePct + temperaturePct + windPct;
    final factor = math.max(0.7, 1 + totalPct);

    return {
      "factor": factor,
      "breakdownPct": {
        "pressure": pressurePct,
        "temperature": temperaturePct,
        "wind": windPct,
        "total": totalPct,
      },
      "inputs": {
        "runway_elev_ft": runwayElevFt,
        "pressure_alt_ft": pressureAltFt,
        "isa_temp_c": isaTempC,
        "oat_c": oatC,
        "headwind_kt": headwindKt,
      },
    };
  }

  /// Runway width / crosswind / airfield altitude hard limits from the BA
  /// Concorde Flying Manual Vol II, 01.01.02 -- shared by takeoff and
  /// landing since the manual states them without a takeoff/landing split.
  /// Each check defaults to true (not violated) when its input is null, so
  /// a runway missing width data in the offline DB, or a METAR with no
  /// usable wind, doesn't get flagged as infeasible on absence of evidence.
  static ({bool widthOk, bool altitudeOk, bool crosswindOk}) _checkHardLimits(
    double? runwayWidthFt,
    RunwayEnvironmentInputs? env,
  ) {
    final widthOk =
        runwayWidthFt == null ||
        runwayWidthFt >= ConcordeConstants.runway.minRunwayWidthFt;
    final elevFt = env?.runwayElevFt;
    final altitudeOk =
        elevFt == null ||
        (elevFt >= ConcordeConstants.runway.minAirfieldAltFt &&
            elevFt <= ConcordeConstants.runway.maxAirfieldAltFt);
    final crosswindKt = env?.crosswindKt;
    final crosswindOk =
        crosswindKt == null ||
        crosswindKt.abs() <= ConcordeConstants.runway.maxCrosswindKt;
    return (widthOk: widthOk, altitudeOk: altitudeOk, crosswindOk: crosswindOk);
  }

  static RunwayFeasibility takeoffFeasibleM(
    double runwayLengthM,
    double takeoffWeightKg, {
    RunwayEnvironmentInputs? env,
    bool useReheat = true,
    double? runwayWidthFt,
  }) {
    final mtow = ConcordeConstants.weights.mtowKg;
    final baseReq = ConcordeConstants.runway.minTakeoffMAtMtow.toDouble();
    final ratio = (takeoffWeightKg / mtow).clamp(0.5, 1.2);

    // Scale required distance based on reheat availability.
    // Without reheat, required distance increases by ~35%.
    final reheatFactor = useReheat ? 1.0 : 1.35;

    final baseRequired = baseReq * ratio * reheatFactor;
    final correction = runwayLengthCorrectionFactor("takeoff", env);
    final required = baseRequired * (correction["factor"] as double);
    final limits = _checkHardLimits(runwayWidthFt, env);

    // If reheat is off and weight is too high (above 155,000 kg),
    // Concorde cannot climb out safely without afterburners, making it unfeasible.
    // Narrow runway width is a caution, not a hard reject: it's surfaced to the
    // crew via widthOk but doesn't gate feasibility the way altitude/crosswind do.
    final feasible =
        (runwayLengthM >= required) &&
        (useReheat || takeoffWeightKg < 155000) &&
        limits.altitudeOk &&
        limits.crosswindOk;

    return RunwayFeasibility(
      baseRequiredLengthMEst: baseRequired,
      requiredLengthMEst: required,
      runwayLengthM: runwayLengthM,
      feasible: feasible,
      correctionFactor: correction["factor"] as double,
      correctionBreakdownPct: Map<String, double>.from(
        correction["breakdownPct"],
      ),
      correctionInputs: Map<String, dynamic>.from(correction["inputs"]),
      widthOk: limits.widthOk,
      altitudeOk: limits.altitudeOk,
      crosswindOk: limits.crosswindOk,
    );
  }

  static RunwayFeasibility landingFeasibleM(
    double runwayLengthM,
    double landingWeightKg, {
    RunwayEnvironmentInputs? env,
    double? runwayWidthFt,
  }) {
    final mlw = ConcordeConstants.weights.mlwKg;
    final baseReq = ConcordeConstants.runway.minLandingMAtMlw.toDouble();
    final ratio = (landingWeightKg / mlw).clamp(0.6, 1.3);
    final baseRequired = baseReq * math.pow(ratio, 1.15);
    final correction = runwayLengthCorrectionFactor("landing", env);
    final required = baseRequired * (correction["factor"] as double);
    final limits = _checkHardLimits(runwayWidthFt, env);
    return RunwayFeasibility(
      baseRequiredLengthMEst: baseRequired,
      requiredLengthMEst: required,
      runwayLengthM: runwayLengthM,
      // Narrow runway width is a caution, not a hard reject: see takeoffFeasibleM.
      feasible:
          runwayLengthM >= required &&
          limits.altitudeOk &&
          limits.crosswindOk,
      correctionFactor: correction["factor"] as double,
      correctionBreakdownPct: Map<String, double>.from(
        correction["breakdownPct"],
      ),
      correctionInputs: Map<String, dynamic>.from(correction["inputs"]),
      widthOk: limits.widthOk,
      altitudeOk: limits.altitudeOk,
      crosswindOk: limits.crosswindOk,
    );
  }
}
