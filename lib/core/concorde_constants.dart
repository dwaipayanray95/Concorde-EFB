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
}

class _Runway {
  const _Runway();
  final int minTakeoffMAtMtow = 3597; // Math.round(11800 * 0.3048)
  final int minLandingMAtMlw = 2200;
}
