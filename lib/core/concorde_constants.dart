class ConcordeConstants {
  static const weights = _Weights();
  static const speeds = _Speeds();
  static const fuel = _Fuel();
  static const runway = _Runway();
}

class _Weights {
  const _Weights();
  // Source: BA Concorde Flying Manual Vol II, "Operating Limitations"
  // 01.01.01 "Maximum Permissible Weights" -- Start of Take-off 185,070 kg,
  // Landing 111,130 kg, Zero Fuel 92,080 kg.
  final double mtowKg = 185070;
  final double mlwKg = 111130;
  final double fuelCapacityKg = 95681;
  final double oewKg = 78700;
  final int paxFullCount = 100;
  final double paxMassKg = 84;
}

class _Speeds {
  const _Speeds();
  final double cruiseMach = 2.04;
  final double cruiseTasKt = 1164;

  /// Maximum operating Mach number (BA Flying Manual: MMO 2.04).
  final double mmo = 2.04;

  /// Maximum landing-gear extended speed (kt IAS).
  final double vleKt = 270;
}

class _Fuel {
  const _Fuel();

  // ---------------------------------------------------------------------
  // Phase model (4 engines combined). Calibrated so a full LHR-JFK sector
  // (~3,150 nm flown) lands at ~70-75 t trip fuel / ~3h10 airborne, which
  // matches published averages (~20-22 t/h whole-flight burn, "about a
  // quarter to a third of the fuel used to reach Mach 2", 95.7 t capacity
  // arriving with ~10-15 t). Sources: concordesst.com powerplant tables,
  // BA Concorde Flying Manual / DC Designs manual worked examples,
  // published BA/AF block figures. Indicative, not certified data.
  // ---------------------------------------------------------------------

  /// Engines at ground idle (4 x ~1,100 kg/h) -- taxi and Flight Monitor
  /// "on ground" phase.
  final double idleFuelFlowKgH = 4400.0;

  /// Subsonic climb (dry power) to the transonic acceleration level.
  final double climbFuelFlowKgH = 26000.0;

  /// Takeoff roll + initial climb in full reheat (~1.5 min at ~80-90 t/h),
  /// added to the departure climb only (not to an alternate climb-out).
  final double takeoffAllowanceKg = 2000.0;

  /// Transonic acceleration M0.95 -> M2.0 (reheat on to ~M1.7, then
  /// max-dry climb). Average over the whole phase at altitude -- full
  /// sea-level reheat (~90 t/h) is far higher than what the engines can
  /// burn at FL280-FL500, so the sea-level figure is NOT used here.
  final double transonicAccelFuelFlowKgH = 60000.0;

  /// Full-reheat sea-level figure (4 x 22,500 kg/h) -- only used by the
  /// live Flight Monitor when reheat is actually lit.
  final double reheatFuelFlowKgH = 90000.0;

  /// Steady Mach 2 supercruise. Heavy/low at the start of cruise
  /// (~21 t/h at FL500), light/high at the end (~17.5 t/h at FL600;
  /// published "~4,800 US gal/h" at FL600 ~= 14.5-18 t/h).
  final double supersonicCruiseFuelFlowKgHAtFl500 = 21000.0;
  final double supersonicCruiseFuelFlowKgHAtFl600 = 17500.0;

  /// Subsonic cruise (M0.95, FL250-FL390): Concorde is inefficient
  /// subsonic -- ~15 t/h at ~550 kt TAS ~= 27 kg/nm.
  final double subsonicCruiseFuelFlowKgH = 15000.0;

  /// Deceleration + descent + approach average. Idle descent can be as low
  /// as ~4.5 t/h ("as low as 10,000 lb/h" per the manual), but the
  /// approach is flown on the back of the drag curve at high thrust, so
  /// the whole-phase average is higher.
  final double descentFuelFlowKgH = 8500.0;

  /// Holding / reserve burn: 30 min subsonic hold ~= 6,000 kg.
  final double holdingFuelFlowKgH = 12000.0;

  /// Missed approach + go-around allowance added to the alternate leg.
  final double missedApproachKg = 1000.0;

  final int reheatMinutesCap = 25;

  /// Standard BA/AF Concorde final reserve (30 min hold) = 6,000 kg.
  final double defaultFinalReserveKg = 6000.0;

  /// Alternates beyond this are flagged as outside a sensible diversion
  /// range for Concorde dispatch.
  final double maxSensibleAlternateNm = 500.0;
}

class _Runway {
  const _Runway();
  final int minTakeoffMAtMtow = 3597; // Math.round(11800 * 0.3048)
  final int minLandingMAtMlw = 2200;

  // Source: BA Concorde Flying Manual Vol II, "Operating Limitations"
  // 01.01.02 "Airplane General / Performance".
  final double minRunwayWidthFt = 150;
  final double maxCrosswindKt = 30;

  /// Maximum tailwind component for takeoff and landing -- 10 kt (BA
  /// Concorde Flying Manual, Operating Limitations).
  final double maxTailwindKt = 10;
  final double minAirfieldAltFt = -1000;
  final double maxAirfieldAltFt = 8000;
}
