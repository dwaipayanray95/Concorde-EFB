import 'dart:math' as math;
import '../models/concorde_models.dart';
import 'concorde_constants.dart';
import 'metar_parser.dart';

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

  // ---------------------------------------------------------------------
  // Atmosphere / speed helpers
  // ---------------------------------------------------------------------

  /// ISA speed of sound (kt) at a flight level. Temperature lapses at
  /// 1.98 C/1000 ft to the tropopause (36,089 ft), constant -56.5 C above.
  static double speedOfSoundKtAtFL(double fl) {
    final altFt = math.max(fl, 0.0) * 100;
    final tempK = altFt >= 36089 ? 216.65 : 288.15 - 0.0019812 * altFt;
    return 661.47 * math.sqrt(tempK / 288.15);
  }

  /// Cruise TAS for a flight level. Supersonic levels (FL410+) are flown at
  /// the cruise Mach, which in the isothermal stratosphere is the same TAS
  /// at every level (~1,170 kt at M2.04). Below FL410 Concorde cruises
  /// subsonic at M0.95 (FL250+), slower lower down.
  static double cruiseTasKtForFL(double fl) {
    final clamped = clampCruiseFL(fl);
    if (clamped >= supersonicMinFl) {
      return ConcordeConstants.speeds.cruiseMach * speedOfSoundKtAtFL(clamped);
    }
    final mach = clamped >= 250
        ? subsonicCruiseMach
        : math.max(0.55, subsonicCruiseMach * clamped / 250);
    return mach * speedOfSoundKtAtFL(clamped);
  }

  /// Steady cruise fuel flow (4 engines, kg/h) at a given FL. Supersonic:
  /// ~21 t/h at FL500 (start of cruise, heavy) tapering to ~17.5 t/h at
  /// FL600 (end of cruise-climb, light), and higher if held lower than
  /// FL500. Subsonic (below FL410): flat M0.95 figure.
  static double cruiseFuelFlowKgHAtFL(double fl) {
    final f = ConcordeConstants.fuel;
    if (fl < supersonicMinFl) return f.subsonicCruiseFuelFlowKgH;
    final hi = f.supersonicCruiseFuelFlowKgHAtFl500;
    final lo = f.supersonicCruiseFuelFlowKgHAtFl600;
    final perFl = (hi - lo) / 100;
    final clamped = fl.clamp(supersonicMinFl, 600).toDouble();
    return hi - perFl * (clamped - 500);
  }

  static double cruiseTimeHours(double distanceNM, {double? tasKT}) {
    final speed = tasKT ?? ConcordeConstants.speeds.cruiseTasKt;
    if (speed <= 0) throw Exception("TAS must be positive");
    return distanceNM / speed;
  }

  // ---------------------------------------------------------------------
  // Mission profile
  // ---------------------------------------------------------------------

  static const double supersonicMinFl = 410;
  static const double subsonicCruiseMach = 0.95;

  /// Subsonic level used when a supersonic FL was selected but the sector
  /// is too short to go supersonic.
  static const double subsonicFallbackFl = 290;

  /// Level where the reheat goes on for the transonic acceleration:
  /// FL240 at M0.95 (DC Designs manual tutorial), reheat off at M1.7.
  static const double transonicStartFl = 240;

  /// Level where Mach 2 cruise-climb begins (heavy aircraft).
  static const double cruiseClimbStartFl = 500;
  static const double cruiseClimbStepFl = 20;

  /// Transonic acceleration FL280/M0.95 -> FL500/M2.0: ~16 min, ~220 nm.
  static const double transonicAccelNm = 220;
  static const double transonicAccelTimeH = 16 / 60;

  /// Shortest supersonic cruise worth planning after climb + accel and
  /// before the deceleration.
  static const double minSupersonicCruiseNm = 100;
  static const double minSubsonicCruiseNm = 20;

  /// Takeoff + climb at ~2,000 fpm average (departure procedures, 250 kt
  /// below FL100 included), ~360 kt average ground speed.
  static ProfileSegment estimateClimb(
    double toAltFt, {
    double avgFpm = 2000,
    double avgGSkt = 360,
  }) {
    final tH = math.max(toAltFt, 0.0) / math.max(avgFpm, 100.0) / 60.0;
    return ProfileSegment(timeH: tH, distNm: tH * math.max(avgGSkt, 200.0));
  }

  /// Deceleration + descent + approach: 3 nm per 1,000 ft plus 30 nm for
  /// deceleration/approach. Supersonic descents begin at Mach 2, so the
  /// average ground speed is higher than a subsonic one.
  static ProfileSegment estimateDescent(
    double fromAltFt, {
    double? avgGSkt,
    double bufferNM = 30,
  }) {
    final alt = math.max(fromAltFt, 0.0);
    final dist = alt / 300.0 + bufferNM;
    final gs = avgGSkt ?? (alt >= supersonicMinFl * 100 ? 480.0 : 330.0);
    return ProfileSegment(timeH: dist / math.max(gs, 150.0), distNm: dist);
  }

  /// Highest subsonic FL whose climb + descent (+ a short cruise) fit in
  /// [distanceNM] -- so a 150 nm hop isn't planned with a climb to FL290.
  static double maxSubsonicFlForDistance(double distanceNM) {
    // climb dist = FL*100/2000/60*360 = 0.3*FL ; descent = FL/3 + 30
    final fl = (distanceNM - 30 - minSubsonicCruiseNm) / (0.3 + 1 / 3);
    return ((fl / 10).floor() * 10).clamp(50, 400).toDouble();
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

  /// Distance needed for a supersonic profile topping out at [targetFL].
  static double minSupersonicDistanceNm(double targetFL) =>
      estimateClimb(transonicStartFl * 100).distNm +
      transonicAccelNm +
      minSupersonicCruiseNm +
      estimateDescent(targetFL * 100).distNm;

  /// Phase-by-phase trip fuel and time. Every phase is burn = fuel flow x
  /// phase time, with times from distance / ground speed (no wind):
  ///  supersonic: climb to FL280 -> transonic accel to FL500 (or the
  ///    selected FL if lower) -> Mach 2 cruise-climb to the selected FL ->
  ///    decel/descent/approach.
  ///  subsonic (FL < 410, or the sector is too short for supersonic):
  ///    climb -> M0.95 cruise -> descent. The FL is lowered automatically
  ///    if the sector is too short to reach it.
  static CruiseMissionProfile buildCruiseMissionProfile(
    double plannedDistanceNM,
    double selectedCruiseFL, {
    bool includeTakeoff = true,
  }) {
    final f = ConcordeConstants.fuel;
    final distanceNM = math.max(plannedDistanceNM, 0.0);
    final selectedFL = clampCruiseFL(selectedCruiseFL);

    var supersonic =
        selectedFL >= supersonicMinFl &&
        distanceNM >= minSupersonicDistanceNm(selectedFL);
    var capped = selectedFL >= supersonicMinFl && !supersonic;

    double targetFL;
    double initialFL;
    ProfileSegment climb;
    ProfileSegment accel;
    double accelKg;
    if (supersonic) {
      targetFL = selectedFL;
      initialFL = math.min(cruiseClimbStartFl, targetFL);
      climb = estimateClimb(transonicStartFl * 100);
      accel = const ProfileSegment(
        timeH: transonicAccelTimeH,
        distNm: transonicAccelNm,
      );
      accelKg = accel.timeH * f.transonicAccelFuelFlowKgH;
    } else {
      final wanted = selectedFL >= supersonicMinFl
          ? subsonicFallbackFl
          : selectedFL;
      final maxFl = maxSubsonicFlForDistance(distanceNM);
      targetFL = math.min(wanted, maxFl);
      if (targetFL < wanted) capped = true;
      initialFL = targetFL;
      climb = estimateClimb(targetFL * 100);
      accel = const ProfileSegment(timeH: 0, distNm: 0);
      accelKg = 0;
    }

    final descent = estimateDescent(targetFL * 100);
    final cruiseNM = math.max(
      distanceNM - climb.distNm - accel.distNm - descent.distNm,
      0.0,
    );

    // Cruise-climb: equal distance at each level from the initial to the
    // final FL (Concorde drifts up continuously as it burns off weight).
    final cruiseLevels = buildCruiseClimbLevels(initialFL, targetFL);
    final perLevelNm = cruiseNM / cruiseLevels.length;
    final cruiseSegments = cruiseLevels.map((fl) {
      final tasKT = math.max(cruiseTasKtForFL(fl.toDouble()), 1.0);
      final flowKgH = cruiseFuelFlowKgHAtFL(fl.toDouble());
      final timeH = perLevelNm / tasKT;
      final burnKg = timeH * flowKgH;
      return CruiseClimbSegment(
        fl: fl,
        distNm: perLevelNm,
        timeH: timeH,
        burnKg: burnKg,
        burnKgPerNm: flowKgH / tasKT,
        tasKt: tasKT,
      );
    }).toList();

    final cruiseTimeH = cruiseSegments.fold(0.0, (s, seg) => s + seg.timeH);
    final cruiseKg = cruiseSegments.fold(0.0, (s, seg) => s + seg.burnKg);
    final climbKg =
        climb.timeH * f.climbFuelFlowKgH +
        (includeTakeoff && distanceNM > 0 ? f.takeoffAllowanceKg : 0.0);
    final descentKg = descent.timeH * f.descentFuelFlowKgH;

    final avgCruiseTasKt = cruiseTimeH > 0
        ? cruiseNM / cruiseTimeH
        : cruiseTasKtForFL(targetFL);
    final avgCruiseBurnKgPerNm = cruiseNM > 0
        ? cruiseKg / cruiseNM
        : cruiseFuelFlowKgHAtFL(targetFL) / math.max(avgCruiseTasKt, 1.0);

    return CruiseMissionProfile(
      climb: climb,
      accel: accel,
      cruise: ProfileSegment(timeH: cruiseTimeH, distNm: cruiseNM),
      descent: descent,
      cruiseSegments: cruiseSegments,
      climbKg: climbKg,
      accelKg: accelKg,
      cruiseKg: cruiseKg,
      descentKg: descentKg,
      tripKg: climbKg + accelKg + cruiseKg + descentKg,
      totalTimeH: climb.timeH + accel.timeH + cruiseTimeH + descent.timeH,
      avgCruiseBurnKgPerNm: avgCruiseBurnKgPerNm,
      avgCruiseTasKt: avgCruiseTasKt,
      initialCruiseFl: initialFL.toInt(),
      targetCruiseFl: targetFL.toInt(),
      selectedCruiseFl: selectedFL.toInt(),
      supersonic: supersonic,
      flCappedForDistance: capped,
    );
  }

  /// Alternate fuel: a subsonic diversion profile (climb, M0.95 cruise,
  /// descent -- capped to a sensible level for the distance) plus a
  /// missed-approach allowance.
  static double alternateFuelKg(double alternateNm) {
    if (alternateNm <= 0) return 0.0;
    final profile = buildCruiseMissionProfile(
      alternateNm,
      subsonicFallbackFl,
      includeTakeoff: false,
    );
    return profile.tripKg + ConcordeConstants.fuel.missedApproachKg;
  }

  static BlockFuelBreakdown blockFuelKg(BlockFuelInputs inputs) {
    final altKg = alternateFuelKg(math.max(inputs.alternateNm ?? 0.0, 0.0));
    final contKg =
        inputs.tripKg * math.max((inputs.contingencyPct ?? 0.0) / 100.0, 0.0);
    final taxiKg = math.max(inputs.taxiKg ?? 0.0, 0.0);
    final reserveKg = math.max(inputs.finalReserveKg ?? 0.0, 0.0);
    return BlockFuelBreakdown(
      tripKg: inputs.tripKg,
      taxiKg: taxiKg,
      contingencyKg: contKg,
      finalReserveKg: reserveKg,
      alternateKg: altKg,
      blockKg: inputs.tripKg + taxiKg + contKg + reserveKg + altKg,
    );
  }

  /// Weights from payload + fuel. Fuel above tank capacity can't be
  /// loaded, so it's capped; taxi fuel is burned before the takeoff roll.
  static WeightSummary computeWeights({
    required double paxKg,
    required double plannedFuelKg,
    required double taxiKg,
    required double tripKg,
  }) {
    final w = ConcordeConstants.weights;
    final zfw = w.oewKg + paxKg;
    final fob = math.min(math.max(plannedFuelKg, 0.0), w.fuelCapacityKg);
    final ramp = zfw + fob;
    final tow = ramp - math.min(taxiKg, fob);
    return WeightSummary(
      zfw: zfw,
      fuelOnBoard: fob,
      plannedFuel: plannedFuelKg,
      ramp: ramp,
      tow: tow,
      lw: math.max(zfw, tow - tripKg),
      pax: paxKg,
    );
  }

  /// Endurance from fuel actually on board (capped at capacity): the trip
  /// fuel lasts the planned ETE, anything left over lasts at holding fuel
  /// flow. Required = ETE + (contingency + alternate + final reserve) at
  /// holding flow. Fails when capacity caps the load below block fuel.
  static FuelEndurance computeEndurance({
    required BlockFuelBreakdown fuel,
    required double fuelOnBoardKg,
    required double eteH,
  }) {
    final hold = ConcordeConstants.fuel.holdingFuelFlowKgH;
    final airborne = math.max(0.0, fuelOnBoardKg - fuel.taxiKg);
    final tripRate = eteH > 0 && fuel.tripKg > 0 ? fuel.tripKg / eteH : hold;
    final enduranceH = airborne <= fuel.tripKg
        ? airborne / tripRate
        : eteH + (airborne - fuel.tripKg) / hold;
    final reserves =
        fuel.contingencyKg + fuel.alternateKg + fuel.finalReserveKg;
    return FuelEndurance(
      airborneFuelKg: airborne,
      enduranceH: enduranceH,
      requiredH: eteH + reserves / hold,
    );
  }

  static AlternateStatus alternateStatus({
    required String alternateIcao,
    required String arrivalIcao,
    required bool alternateResolved,
    required double alternateNm,
  }) {
    if (alternateIcao.trim().isEmpty) return AlternateStatus.missing;
    if (alternateIcao == arrivalIcao) return AlternateStatus.sameAsArrival;
    if (!alternateResolved) return AlternateStatus.unknownAirport;
    if (alternateNm > ConcordeConstants.fuel.maxSensibleAlternateNm) {
      return AlternateStatus.tooFar;
    }
    return AlternateStatus.ok;
  }

  /// Planned distance when only the two airports are known: great circle
  /// plus a typical airway inefficiency (~4%) plus SID/STAR/approach track
  /// miles (~40 nm) the great circle doesn't cover.
  static const double routeInefficiencyFactor = 1.04;
  static const double terminalProceduresNm = 40;
  static double estimatedRouteDistanceNm(double greatCircleNm) =>
      greatCircleNm <= 0
      ? 0
      : greatCircleNm * routeInefficiencyFactor + terminalProceduresNm;

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

  /// Takeoff speeds. Stall-referenced speeds scale with sqrt(weight)
  /// (lift = weight at a fixed CL). Reference at MTOW (DC Designs manual
  /// takeoff at 185,066 kg): V1 170 / VR 190 / lift-off ~210-220 kt, so V2
  /// 220. Floors keep V1 above VMCG and V2 above 1.1 VMCA. On wet /
  /// contaminated runways V1 is reduced (less braking available), never
  /// below the floor and always V1 <= VR <= V2.
  static TakeoffSpeeds computeTakeoffSpeeds(
    double towKg, {
    RunwayCondition condition = RunwayCondition.dry,
  }) {
    final s = weightScale(towKg, ConcordeConstants.weights.mtowKg);
    final v2 = math.max(185.0, (220.0 * s).roundToDouble());
    final vr = math.min(v2, math.max(165.0, (190.0 * s).roundToDouble()));
    final v1Reduction = switch (condition) {
      RunwayCondition.dry => 0.0,
      RunwayCondition.wet => 8.0,
      RunwayCondition.contaminated => 15.0,
    };
    final v1 = math.min(
      vr,
      math.max(130.0, (170.0 * s).roundToDouble() - v1Reduction),
    );
    return TakeoffSpeeds(v1: v1, vr: vr, v2: v2);
  }

  /// Landing speeds. VREF scales with sqrt(weight): 195 kt at MLW. The DC
  /// Designs manual gives approach speeds of 150-207 kt depending on
  /// weight (final approach flown at ~200 kt), which this reproduces
  /// (~150 kt at 66 t up to ~200-215 kt at MLW). VAPP = VREF + half the
  /// steady headwind + the full gust increment, minimum +5 kt, maximum
  /// +20 kt (standard wind additive).
  static LandingSpeeds computeLandingSpeeds(
    double lwKg, {
    double? headwindKt,
    double gustIncrementKt = 0,
  }) {
    final s = weightScale(lwKg, ConcordeConstants.weights.mlwKg);
    final vref = math.max(145.0, (195.0 * s).roundToDouble());
    final additive =
        (math.max(headwindKt ?? 0.0, 0.0) / 2 + math.max(gustIncrementKt, 0))
            .clamp(5.0, 20.0);
    return LandingSpeeds(vref: vref, vapp: (vref + additive).roundToDouble());
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
    final tailwindKt = env?.tailwindKt;
    if (tailwindKt != null && tailwindKt > 0) {
      windPct = phase == "takeoff"
          ? math.min(tailwindKt * 0.03, 0.5)
          : math.min(tailwindKt * 0.04, 0.65);
    } else if (headwindKt != null) {
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

    // Wet / contaminated surface: EASA-style factors (wet landing x1.15,
    // CAT.POL.A.235; contaminated distances substantially longer).
    final condition = env?.condition ?? RunwayCondition.dry;
    final surfacePct = switch (condition) {
      RunwayCondition.dry => 0.0,
      RunwayCondition.wet => 0.15,
      RunwayCondition.contaminated => phase == "takeoff" ? 0.30 : 0.40,
    };

    final totalPct = pressurePct + temperaturePct + windPct + surfacePct;
    final factor = math.max(0.7, 1 + totalPct);

    return {
      "factor": factor,
      "breakdownPct": {
        "pressure": pressurePct,
        "temperature": temperaturePct,
        "wind": windPct,
        "surface": surfacePct,
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

  /// Runway width / crosswind / tailwind / airfield altitude hard limits
  /// from the BA Concorde Flying Manual Vol II, 01.01.02 -- shared by
  /// takeoff and landing. Each check defaults to true (not violated) when
  /// its input is null; the UI separately flags missing wind data.
  static ({bool widthOk, bool altitudeOk, bool crosswindOk, bool tailwindOk})
  _checkHardLimits(double? runwayWidthFt, RunwayEnvironmentInputs? env) {
    final r = ConcordeConstants.runway;
    final widthOk =
        runwayWidthFt == null || runwayWidthFt >= r.minRunwayWidthFt;
    final elevFt = env?.runwayElevFt;
    final altitudeOk =
        elevFt == null ||
        (elevFt >= r.minAirfieldAltFt && elevFt <= r.maxAirfieldAltFt);
    final crosswindKt = env?.crosswindKt;
    final crosswindOk =
        crosswindKt == null || crosswindKt.abs() <= r.maxCrosswindKt;
    final tailwindKt = env?.tailwindKt;
    final tailwindOk = tailwindKt == null || tailwindKt <= r.maxTailwindKt;
    return (
      widthOk: widthOk,
      altitudeOk: altitudeOk,
      crosswindOk: crosswindOk,
      tailwindOk: tailwindOk,
    );
  }

  static RunwayFeasibility _feasibility({
    required String phase,
    required double runwayLengthM,
    required double baseRequired,
    required RunwayEnvironmentInputs? env,
    required double? runwayWidthFt,
    bool extraOk = true,
  }) {
    final correction = runwayLengthCorrectionFactor(phase, env);
    final factor = correction["factor"] as double;
    final required = baseRequired * factor;
    final limits = _checkHardLimits(runwayWidthFt, env);
    // Narrow runway width is a caution, not a hard reject: it's surfaced to
    // the crew via widthOk but doesn't gate feasibility.
    return RunwayFeasibility(
      baseRequiredLengthMEst: baseRequired,
      requiredLengthMEst: required,
      runwayLengthM: runwayLengthM,
      feasible:
          runwayLengthM >= required &&
          extraOk &&
          limits.altitudeOk &&
          limits.crosswindOk &&
          limits.tailwindOk,
      correctionFactor: factor,
      correctionBreakdownPct: Map<String, double>.from(
        correction["breakdownPct"],
      ),
      correctionInputs: Map<String, dynamic>.from(correction["inputs"]),
      widthOk: limits.widthOk,
      altitudeOk: limits.altitudeOk,
      crosswindOk: limits.crosswindOk,
      tailwindOk: limits.tailwindOk,
      windDataAvailable: env?.windDataAvailable ?? false,
      condition: env?.condition ?? RunwayCondition.dry,
    );
  }

  /// Takeoff distance scales with weight squared: lift-off speed^2 is
  /// proportional to weight and the available acceleration (thrust/weight)
  /// is inversely proportional to it, so ground roll ~ W^2. Anchored at
  /// 3,597 m (11,800 ft) at MTOW with reheat.
  static RunwayFeasibility takeoffFeasibleM(
    double runwayLengthM,
    double takeoffWeightKg, {
    RunwayEnvironmentInputs? env,
    bool useReheat = true,
    double? runwayWidthFt,
  }) {
    final ratio = (takeoffWeightKg / ConcordeConstants.weights.mtowKg).clamp(
      0.5,
      1.2,
    );
    // Without reheat the takeoff needs ~35% more runway, and above
    // ~155 t a dry-thrust takeoff isn't planned at all (indicative values
    // pending DC Designs data).
    final reheatFactor = useReheat ? 1.0 : 1.35;
    final baseRequired =
        ConcordeConstants.runway.minTakeoffMAtMtow *
        ratio *
        ratio *
        reheatFactor;
    return _feasibility(
      phase: "takeoff",
      runwayLengthM: runwayLengthM,
      baseRequired: baseRequired,
      env: env,
      runwayWidthFt: runwayWidthFt,
      extraOk: useReheat || takeoffWeightKg < 155000,
    );
  }

  /// Landing distance ~ VREF^2 / deceleration, and VREF^2 ~ weight, so it
  /// scales roughly linearly with weight; the slight extra exponent covers
  /// the longer air distance at higher approach speeds. Anchored at
  /// 2,200 m at MLW.
  static RunwayFeasibility landingFeasibleM(
    double runwayLengthM,
    double landingWeightKg, {
    RunwayEnvironmentInputs? env,
    double? runwayWidthFt,
  }) {
    final ratio = (landingWeightKg / ConcordeConstants.weights.mlwKg).clamp(
      0.6,
      1.3,
    );
    final baseRequired =
        ConcordeConstants.runway.minLandingMAtMlw * math.pow(ratio, 1.15);
    return _feasibility(
      phase: "landing",
      runwayLengthM: runwayLengthM,
      baseRequired: baseRequired.toDouble(),
      env: env,
      runwayWidthFt: runwayWidthFt,
    );
  }

  /// Runway environment (pressure, temperature, wind components, surface)
  /// from a raw METAR for a runway heading (true). Wind conventions:
  ///  - no METAR / no wind group -> wind unknown (null), flagged in the UI;
  ///  - VRB wind -> worst case: full speed as tailwind and crosswind;
  ///  - gusts -> gust speed used for the crosswind and tailwind limits.
  static RunwayEnvironmentInputs runwayEnvFromMetar({
    required String metar,
    required double runwayHeadingDeg,
    double? runwayElevFt,
    RunwayConditionMode conditionMode = RunwayConditionMode.auto,
  }) {
    final wind = MetarParser.parseWind(metar);
    final steady = wind.windSpeedKt;
    final gust = math.max(wind.windGustKt ?? 0.0, steady ?? 0.0);
    final gustIncrement = steady == null ? 0.0 : gust - steady;

    double? head;
    double? cross;
    double? tail;
    if (steady != null) {
      if (wind.windDirDeg == null) {
        head = steady >= 3 ? -steady : 0.0;
        cross = steady >= 3 ? gust : 0.0;
        tail = steady >= 3 ? gust : 0.0;
      } else {
        final rad = (wind.windDirDeg! - runwayHeadingDeg) * math.pi / 180;
        head = steady * math.cos(rad);
        cross = (gust * math.sin(rad)).abs();
        tail = math.max(0.0, -gust * math.cos(rad));
      }
    }

    final qnh = MetarParser.parseQnh(metar);
    return RunwayEnvironmentInputs(
      runwayElevFt: runwayElevFt,
      qnh: qnh,
      oatC: MetarParser.parseTempC(metar),
      headwindKt: head,
      crosswindKt: cross,
      tailwindKt: tail,
      gustIncrementKt: gustIncrement,
      condition: resolveRunwayCondition(conditionMode, metar),
      windDataAvailable: steady != null,
    );
  }

  static RunwayCondition resolveRunwayCondition(
    RunwayConditionMode mode,
    String metar,
  ) => switch (mode) {
    RunwayConditionMode.dry => RunwayCondition.dry,
    RunwayConditionMode.wet => RunwayCondition.wet,
    RunwayConditionMode.contaminated => RunwayCondition.contaminated,
    RunwayConditionMode.auto => MetarParser.inferRunwayCondition(metar),
  };
}
