import '../features/flight_monitor/data/models/telemetry_model.dart';

/// One chip on the 13-tank fuel schematic overlay.
class FuelTankChip {
  final String id;
  final int pct;
  final double capacityKg;
  final double left; // percent, matches the vector aircraft outline drawn behind the chips
  final double top;
  final FuelTankGroup group;

  const FuelTankChip({
    required this.id,
    required this.pct,
    required this.capacityKg,
    required this.left,
    required this.top,
    required this.group,
  });

  double get kg => capacityKg * pct / 100.0;
}

enum FuelTankGroup { collector, main, trim }

/// The real DC Designs Concorde fuel system models 13 physical tanks, laid
/// out and captioned in the ops manual's fuel schematic. Capacities are
/// sourced from that manual and sum to the aircraft's real 95,680 kg total
/// (matching [ConcordeConstants.weights.fuelCapacityKg]).
class ConcordeFuelSchematic {
  static const Map<String, double> tankCapacitiesKg = {
    '1': 4800, '2': 4800, '3': 4800, '4': 4800, // collector
    '5': 11000, '6': 11000, '7': 11000, '8': 11000, // main
    '5A': 3000, '7A': 3000, // main (wing tip)
    '9': 4000, '10': 5000, '11': 17480, // trim
  };

  static const Map<String, FuelTankGroup> tankGroups = {
    '1': FuelTankGroup.collector, '2': FuelTankGroup.collector,
    '3': FuelTankGroup.collector, '4': FuelTankGroup.collector,
    '5': FuelTankGroup.main, '5A': FuelTankGroup.main, '6': FuelTankGroup.main,
    '7': FuelTankGroup.main, '7A': FuelTankGroup.main, '8': FuelTankGroup.main,
    '9': FuelTankGroup.trim, '10': FuelTankGroup.trim, '11': FuelTankGroup.trim,
  };

  /// Plan-view chip positions (percent of the schematic image), taken
  /// directly from the DC Designs ops manual's fuel schematic layout.
  static const Map<String, List<double>> tankPositions = {
    '9': [48.8, 19.3], '10': [36, 27.8], '1': [34.4, 33.8], '4': [62, 33.8],
    '5': [35.8, 41.6], '8': [62.8, 41.6], '6': [28, 55.3], '7': [67.9, 55.3],
    '5A': [10.4, 63.5], '7A': [86.4, 63.5], '2': [37.6, 65.7], '3': [58.4, 65.7],
    '11': [47.7, 78.1],
  };

  static double get totalCapacityKg =>
      tankCapacitiesKg.values.fold(0.0, (s, v) => s + v);

  /// The SimConnect bridge only exposes MSFS's 5 stock tank levels (left
  /// main, right main, center ×3) — the DC Designs addon's 13 individual
  /// tanks aren't available as named SimVars. Each of the 13 schematic tanks
  /// is therefore approximated from whichever real channel feeds its group
  /// and side, on the assumption that tanks within a feed group drain
  /// roughly together. This keeps the schematic live and representative
  /// without fabricating independent random values.
  static List<FuelTankChip> computeTankFills(TelemetryModel t) {
    double fillFor(String id) {
      switch (id) {
        // Collector tanks 1&2 feed from the left side, 3&4 from the right.
        case '1':
        case '2':
          return t.fuelLeftTank;
        case '3':
        case '4':
          return t.fuelRightTank;
        // Main tanks split left/right, blended with the center tank they
        // also draw from.
        case '5':
        case '5A':
        case '6':
          return (t.fuelLeftTank + t.fuelCenterTank) / 2.0;
        case '7':
        case '7A':
        case '8':
          return (t.fuelRightTank + t.fuelCenterTank) / 2.0;
        // Trim tanks: 9 (nose) & 10 forward, 11 (tail) aft.
        case '9':
        case '10':
          return t.fuelTrimForward;
        case '11':
          return t.fuelTrimAft;
        default:
          return 0.0;
      }
    }

    return tankCapacitiesKg.keys.map((id) {
      final fill = fillFor(id).clamp(0.0, 1.0);
      final pos = tankPositions[id]!;
      return FuelTankChip(
        id: id,
        pct: (fill * 100).round(),
        capacityKg: tankCapacitiesKg[id]!,
        left: pos[0],
        top: pos[1],
        group: tankGroups[id]!,
      );
    }).toList();
  }

  static double totalFuelKg(List<FuelTankChip> chips) =>
      chips.fold(0.0, (s, c) => s + c.kg);
}
