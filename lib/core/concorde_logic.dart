import 'dart:math' as math;
import '../models/concorde_models.dart';
import 'concorde_constants.dart';

class ConcordeLogic {
  static double toRad(double deg) => (deg * math.pi) / 180;
  static double nmFromKm(double km) => km * 0.539957;

  static double greatCircleNM(double lat1, double lon1, double lat2, double lon2) {
    const rKm = 6371.0088;
    final phi1 = toRad(lat1);
    final phi2 = toRad(lat2);
    final dphi = toRad(lat2 - lat1);
    final dlambda = toRad(lon2 - lon1);
    final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2) * math.sin(dlambda / 2);
    return nmFromKm(2 * rKm * math.asin(math.sqrt(a)));
  }

  static double initialBearingDeg(double lat1, double lon1, double lat2, double lon2) {
    final phi1 = toRad(lat1);
    final phi2 = toRad(lat2);
    final dlambda = toRad(lon2 - lon1);
    final y = math.sin(dlambda) * math.cos(phi2);
    final x = math.cos(phi1) * math.sin(phi2) - math.sin(phi1) * math.cos(phi2) * math.cos(dlambda);
    final theta = math.atan2(y, x);
    final deg = (theta * 180) / math.pi;
    return deg >= 0 ? deg % 360 : (deg % 360) + 360;
  }

  static String inferDirectionEW(double lat1, double lon1, double lat2, double lon2) {
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

  static double altitudeBurnFactor(double cruiseFL) {
    final fl = cruiseFL.clamp(300, 650).toDouble();
    final x = (fl - 450) / (600 - 450);
    return 1.2 - 0.2 * math.max(0.0, math.min(1.0, x));
  }

  static double cruiseTimeHours(double distanceNM, {double? tasKT}) {
    final speed = tasKT ?? ConcordeConstants.speeds.cruiseTasKt;
    if (speed <= 0) throw Exception("TAS must be positive");
    return distanceNM / speed;
  }

  static ProfileSegment estimateClimb(double cruiseAltFt, {double avgFpm = 2500, double avgGSkt = 450}) {
    final tH = math.max(cruiseAltFt, 0.0) / math.max(avgFpm, 100.0) / 60.0;
    final dNM = tH * math.max(avgGSkt, 200.0);
    return ProfileSegment(timeH: tH, distNm: dNM);
  }

  static ProfileSegment estimateDescent(double cruiseAltFt, {double avgGSkt = 420, double bufferNM = 30}) {
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

  static double cruiseBurnKgPerNmAtFL(double fl) {
    final base = ConcordeConstants.fuel.burnKgPerNm * altitudeBurnFactor(fl);
    final shortSectorPenalty = fl < 500 ? 1.15 : 1.0;
    return base * shortSectorPenalty;
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

  static CruiseMissionProfile buildCruiseMissionProfile(double plannedDistanceNM, double selectedCruiseFL) {
    final distanceNM = math.max(plannedDistanceNM, 0.0);
    final targetFL = clampCruiseFL(selectedCruiseFL);
    final initialCruiseFL = targetFL >= cruiseClimbStartFl ? cruiseClimbStartFl : targetFL;

    final climb = estimateClimb(initialCruiseFL * 100);
    final descent = estimateDescent(math.max(targetFL, initialCruiseFL) * 100);

    final coreRemainingNM = math.max(distanceNM - (climb.distNm + descent.distNm), 0.0);
    final useSupersonicAccel = targetFL >= cruiseClimbStartFl;
    final accelDistNM = useSupersonicAccel ? math.min(suprAccelNm, coreRemainingNM * 0.4) : 0.0;
    final accelTimeH = (useSupersonicAccel && suprAccelNm > 0) ? suprAccelTimeH * (accelDistNM / suprAccelNm) : 0.0;
    final accelBurnKg = accelDistNM * (cruiseBurnKgPerNmAtFL(initialCruiseFL) * 2.1);

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
      final burnKgPerNm = cruiseBurnKgPerNmAtFL(fl.toDouble());
      final timeH = segmentNM / tasKT;
      final burnKg = segmentNM * burnKgPerNm;
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

    final climbKg = climb.distNm * cruiseBurnKgPerNmAtFL(initialCruiseFL) * ConcordeConstants.fuel.climbFactor;
    final descentKg = descent.distNm * cruiseBurnKgPerNmAtFL(math.max(targetFL, initialCruiseFL)) * ConcordeConstants.fuel.descentFactor;

    final avgCruiseBurnKgPerNm = cruiseNM > 0 ? cruiseKg / cruiseNM : cruiseBurnKgPerNmAtFL(targetFL);
    final avgCruiseTasKt = cruiseTimeH > 0 ? cruiseNM / cruiseTimeH : cruiseTasKtForFL(targetFL);

    final tripKg = math.max(climbKg + accelBurnKg + cruiseKg + descentKg, 0.0);
    final totalTimeH = math.max(climb.timeH + accelTimeH + cruiseTimeH + descent.timeH, 0.0);

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
    final burn = inputs.burnKgPerNm ?? ConcordeConstants.fuel.burnKgPerNm;
    final altKg = math.max(inputs.alternateNm ?? 0.0, 0.0) * burn;
    final contKg = inputs.tripKg * math.max((inputs.contingencyPct ?? 0.0) / 100.0, 0.0);
    final total = inputs.tripKg + (inputs.taxiKg ?? 0.0) + contKg + (inputs.finalReserveKg ?? 0.0) + altKg;
    return BlockFuelBreakdown(
      tripKg: inputs.tripKg,
      taxiKg: inputs.taxiKg ?? 0.0,
      contingencyKg: contKg,
      finalReserveKg: inputs.finalReserveKg ?? 0.0,
      alternateKg: altKg,
      blockKg: total,
    );
  }

  static double weightScale(double actual, double reference) {
    if (actual <= 0 || reference <= 0) return 1.0;
    return math.sqrt(actual / reference);
  }

  static Map<String, double> computeTakeoffSpeeds(double towKg) {
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

  static Map<String, dynamic> runwayLengthCorrectionFactor(String phase, RunwayEnvironmentInputs? env) {
    final runwayElevFt = env?.runwayElevFt ?? 0.0;
    final qnhHpa = qnhToHpa(env?.qnh);
    final pressureAltFt = qnhHpa == null ? runwayElevFt : runwayElevFt + (1013.25 - qnhHpa) * 30;
    final isaTempC = isaTempCAtElevationFt(runwayElevFt);
    final oatC = env?.oatC;
    final headwindKt = env?.headwindKt;

    var pressurePctRaw = 0.0;
    pressurePctRaw = phase == "takeoff" ? (pressureAltFt / 1000) * 0.012 : (pressureAltFt / 1000) * 0.007;
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
        windPct = phase == "takeoff" ? -math.min(headwindKt * 0.01, 0.2) : -math.min(headwindKt * 0.01, 0.15);
      } else {
        final tailwind = headwindKt.abs();
        windPct = phase == "takeoff" ? math.min(tailwind * 0.03, 0.5) : math.min(tailwind * 0.04, 0.65);
      }
    }

    final totalPct = pressurePct + temperaturePct + windPct;
    final factor = math.max(0.7, 1 + totalPct);

    return {
      "factor": factor,
      "breakdownPct": {"pressure": pressurePct, "temperature": temperaturePct, "wind": windPct, "total": totalPct},
      "inputs": {
        "runway_elev_ft": runwayElevFt,
        "pressure_alt_ft": pressureAltFt,
        "isa_temp_c": isaTempC,
        "oat_c": oatC,
        "headwind_kt": headwindKt,
      }
    };
  }

  static RunwayFeasibility takeoffFeasibleM(
    double runwayLengthM, 
    double takeoffWeightKg, {
    RunwayEnvironmentInputs? env,
    bool useReheat = true,
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
    
    // If reheat is off and weight is too high (above 155,000 kg),
    // Concorde cannot climb out safely without afterburners, making it unfeasible.
    final feasible = (runwayLengthM >= required) && (useReheat || takeoffWeightKg < 155000);
    
    return RunwayFeasibility(
      baseRequiredLengthMEst: baseRequired,
      requiredLengthMEst: required,
      runwayLengthM: runwayLengthM,
      feasible: feasible,
      correctionFactor: correction["factor"] as double,
      correctionBreakdownPct: Map<String, double>.from(correction["breakdownPct"]),
      correctionInputs: Map<String, dynamic>.from(correction["inputs"]),
    );
  }

  static RunwayFeasibility landingFeasibleM(double runwayLengthM, double landingWeightKg, {RunwayEnvironmentInputs? env}) {
    final mlw = ConcordeConstants.weights.mlwKg;
    final baseReq = ConcordeConstants.runway.minLandingMAtMlw.toDouble();
    final ratio = (landingWeightKg / mlw).clamp(0.6, 1.3);
    final baseRequired = baseReq * math.pow(ratio, 1.15);
    final correction = runwayLengthCorrectionFactor("landing", env);
    final required = baseRequired * (correction["factor"] as double);
    return RunwayFeasibility(
      baseRequiredLengthMEst: baseRequired,
      requiredLengthMEst: required,
      runwayLengthM: runwayLengthM,
      feasible: runwayLengthM >= required,
      correctionFactor: correction["factor"] as double,
      correctionBreakdownPct: Map<String, double>.from(correction["breakdownPct"]),
      correctionInputs: Map<String, dynamic>.from(correction["inputs"]),
    );
  }
}
