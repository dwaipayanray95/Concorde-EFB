class ConcordeConstants {
  static const weights = _Weights();
  static const speeds = _Speeds();
  static const fuel = _Fuel();
  static const runway = _Runway();
}

class _Weights {
  const _Weights();
  final double mtowKg = 185066;
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
}

class _Fuel {
  const _Fuel();

  /// Whole-mission average (95,681 kg capacity / 3,900 nm published range —
  /// matches the manual's own "46.85 lb/mi (13.2 kg/km)" spec figure). This
  /// is NOT a pure cruise rate — it has climb/reheat overhead baked in — so
  /// it's only appropriate for a short, low-altitude/subsonic leg where
  /// climb+descent dominate rather than sustained supersonic cruise, i.e.
  /// the alternate-airport diversion leg in [ConcordeLogic.blockFuelKg].
  /// The main trip profile uses the phase-based hourly rates below instead.
  final double alternateBurnKgPerNm = 24.45;

  final int reheatMinutesCap = 25;

  // Phase-based fuel flow (4 engines combined), sourced from the DC Designs
  // manual's own worked examples cross-checked against real Olympus 593
  // engine specs (concordesst.com powerplant table) and published real-world
  // block fuel for transatlantic Concorde flights (~91-92 t / ~3.5h):
  //   - idle:   1,100 kg/h/engine x4  (concordesst.com "Idle Power")
  //   - climb:  10,500 kg/h/engine x4 (concordesst.com "Full Power", no
  //     reheat -- the subsonic/low-supersonic climb before the transonic
  //     accel burst, not yet in supercruise)
  //   - reheat: 22,500 kg/h/engine x4 (concordesst.com "Full Re-heated
  //     Power" -- the ~90 nm transonic acceleration burst through Mach 2)
  //   - cruise: ~18,000-20,500 kg/h total at steady Mach 2 (the manual's own
  //     "10,000 lb/engine/h" worked example, corroborated by real BA flight
  //     data and by back-solving real block fuel/flight-time). This is
  //     LOWER than "climb" full-power because level supercruise only needs
  //     enough thrust to overcome drag, not max continuous thrust.
  //   - descent: manual states "as low as 10,000 lb/h TOTAL" during descent,
  //     which also matches concordesst.com's idle-power figure almost
  //     exactly (4,400 kg/h) -- engines are throttled back to near-idle.
  final double idleFuelFlowKgH = 4400.0;
  final double climbFuelFlowKgH = 42000.0;
  final double reheatFuelFlowKgH = 90000.0;
  final double cruiseFuelFlowKgHAtFl500 = 20500.0;
  final double cruiseFuelFlowKgHAtFl600 = 17000.0;
  final double descentFuelFlowKgH = 4536.0;
}

class _Runway {
  const _Runway();
  final int minTakeoffMAtMtow = 3597; // Math.round(11800 * 0.3048)
  final int minLandingMAtMlw = 2200;
}
