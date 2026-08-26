import '../features/flight_monitor/data/models/telemetry_model.dart';

/// One chip on the 13-tank fuel schematic overlay. [kg] is the
/// authoritative value (real telemetry when available); [pct] is derived
/// from it for display, rather than the other way around, so real per-tank
/// readings aren't lossy-rounded through a percentage first.
class FuelTankChip {
  final String id;
  final double kg;
  final double capacityKg;
  final double left; // percent, matches the manual fuel schematic image drawn behind the chips
  final double top;
  final FuelTankGroup group;

  const FuelTankChip({
    required this.id,
    required this.kg,
    required this.capacityKg,
    required this.left,
    required this.top,
    required this.group,
  });

  int get pct => capacityKg > 0 ? (kg / capacityKg * 100).round().clamp(0, 100) : 0;
}

enum FuelTankGroup { fuelTransfer, main, trim }

/// The real DC Designs Concorde fuel system models 13 physical tanks, laid
/// out and captioned in the ops manual's fuel schematic. Capacities are
/// sourced from that manual and sum to the aircraft's real 95,680 kg total
/// (matching [ConcordeConstants.weights.fuelCapacityKg]).
class ConcordeFuelSchematic {
  static const Map<String, double> tankCapacitiesKg = {
    '1': 4800, '2': 4800, '3': 4800, '4': 4800, // fuel transfer
    '5': 11000, '6': 11000, '7': 11000, '8': 11000, // main
    '5A': 3000, '7A': 3000, // main (wing tip)
    '9': 4000, '10': 5000, '11': 17480, // trim
  };

  static const Map<String, FuelTankGroup> tankGroups = {
    '1': FuelTankGroup.fuelTransfer, '2': FuelTankGroup.fuelTransfer,
    '3': FuelTankGroup.fuelTransfer, '4': FuelTankGroup.fuelTransfer,
    '5': FuelTankGroup.main, '5A': FuelTankGroup.main, '6': FuelTankGroup.main,
    '7': FuelTankGroup.main, '7A': FuelTankGroup.main, '8': FuelTankGroup.main,
    '9': FuelTankGroup.trim, '10': FuelTankGroup.trim, '11': FuelTankGroup.trim,
  };

  /// Plan-view chip positions (percent of the schematic outline), measured
  /// directly off the "Fuel Tank Layout Schematic" diagram on page 54 of the
  /// DC Designs ops manual (pixel-analyzed from the source PDF render).
  static const Map<String, List<double>> tankPositions = {
    '9': [49.0, 24.5], '10': [49.4, 30.9], '1': [40.3, 36.2], '4': [57.5, 36.3],
    '5': [40.5, 42.0], '8': [56.0, 41.6], '6': [35.0, 51.5], '7': [63.5, 51.1],
    '5A': [23.5, 57.5], '7A': [74.4, 57.7], '2': [41.1, 58.5], '3': [56.3, 58.4],
    '11': [48.6, 69.6],
  };

  static double get totalCapacityKg =>
      tankCapacitiesKg.values.fold(0.0, (s, v) => s + v);

  /// Real per-tank weight, read directly from MSFS's
  /// FUELSYSTEM TANK WEIGHT:N SimVar for each of the 13 Concorde
  /// tanks (see [TelemetryModel.fuelTanksKg] / `tools/simbridge/msfs_bridge.py`),
  /// is used whenever present. Falls back to approximating from the 5
  /// aggregate stock SimVars (left main, right main, center ×3) — spread
  /// across each tank's feed group — only for tanks the bridge hasn't
  /// reported (e.g. an older recording made before this was added).
  static List<FuelTankChip> computeTankFills(TelemetryModel t) {
    double approxFillFor(String id) {
      switch (id) {
        // Fuel transfer tanks 1&2 feed from the left side, 3&4 from the right.
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
      final capacity = tankCapacitiesKg[id]!;
      final realKg = t.fuelTanksKg[id];
      // approxFillFor() returns the raw telemetry value, which the bridge
      // sends as a 0-100 percent (not a 0-1 fraction) — divide before use.
      final kg = realKg ?? (approxFillFor(id) / 100.0).clamp(0.0, 1.0) * capacity;
      final pos = tankPositions[id]!;
      return FuelTankChip(
        id: id,
        kg: kg.clamp(0.0, capacity),
        capacityKg: capacity,
        left: pos[0],
        top: pos[1],
        group: tankGroups[id]!,
      );
    }).toList();
  }

  static double totalFuelKg(List<FuelTankChip> chips) =>
      chips.fold(0.0, (s, c) => s + c.kg);

  /// [tankPositions] is authored nose-up (x% = left/right across the
  /// wingspan, y% = nose-to-tail) to match the source manual image. The card
  /// renders that same image rotated 90° counter-clockwise to landscape
  /// (nose left) so more of the airframe is visible in a wide card — this
  /// fractional transform is the exact equivalent of that rotation, used by
  /// the chip overlay so labels always land on the right tank. Returns
  /// fractional (0-1) coordinates.
  static ({double fx, double fy}) landscapeFraction(double xPct, double yPct) {
    return (fx: yPct / 100, fy: 1 - xPct / 100);
  }
}
