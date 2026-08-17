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
  final double burnKgPerNm = 24.45;
  final double climbFactor = 1.7;
  final double descentFactor = 0.5;
  final int reheatMinutesCap = 25;

  /// Burn multiplier applied to cruise burn rate during the transonic
  /// reheat acceleration (Mach ~1.7 -> 2.0), when all 4 afterburners are lit.
  final double reheatBurnMultiplier = 2.1;

  /// Usable fuel tank capacities in kg, keyed to match [TelemetryModel]'s
  /// tank fill-percentage fields. Single source of truth so the LCD fuel
  /// and endurance modules can't drift apart.
  final Map<String, double> tankCapacitiesKg = const {
    'left': 17483.0,
    'right': 17483.0,
    'center': 11793.0,
    'trimForward': 10000.0,
    'trimAft': 5681.0,
  };
}

class _Runway {
  const _Runway();
  final int minTakeoffMAtMtow = 3597; // Math.round(11800 * 0.3048)
  final int minLandingMAtMlw = 2200;
}
