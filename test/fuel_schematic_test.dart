import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/core/concorde_fuel_schematic.dart';
import 'package:concorde_efb/features/flight_monitor/data/models/telemetry_model.dart';

TelemetryModel _telemetry({
  Map<String, double> fuelTanksKg = const {},
  double fuelLeftTank = 0.0,
  double fuelRightTank = 0.0,
  double fuelCenterTank = 0.0,
  double fuelTrimForward = 0.0,
  double fuelTrimAft = 0.0,
}) {
  return TelemetryModel(
    timestamp: 0,
    altitude: 0,
    ias: 0,
    tas: 0,
    gs: 0,
    heading: 0,
    vs: 0,
    pitch: 0,
    roll: 0,
    latitude: 0,
    longitude: 0,
    gForce: 1.0,
    gearPosition: 0,
    flapsPosition: 0,
    zuluTime: '00:00:00',
    mach: 0,
    tat: 15.0,
    cgPct: 53.0,
    cgAftLimit: 59.0,
    cgFwdLimit: 52.0,
    fuelBurnTotal: 0,
    reheatActive: const [false, false, false, false],
    snootAngle: 0,
    fuelLeftTank: fuelLeftTank,
    fuelRightTank: fuelRightTank,
    fuelCenterTank: fuelCenterTank,
    fuelTrimForward: fuelTrimForward,
    fuelTrimAft: fuelTrimAft,
    fuelTanksKg: fuelTanksKg,
    isLanding: false,
    touchdownVS: 0,
    touchdownPitch: 0,
    touchdownGForce: 0,
  );
}

void main() {
  group('ConcordeFuelSchematic.tankCapacitiesKg', () {
    test('sums to the real 95,680 kg total fuel capacity', () {
      expect(ConcordeFuelSchematic.totalCapacityKg, closeTo(95680, 0.01));
    });

    test('every tank has a matching group entry', () {
      for (final id in ConcordeFuelSchematic.tankCapacitiesKg.keys) {
        expect(
          ConcordeFuelSchematic.tankGroups.containsKey(id),
          isTrue,
          reason: 'tank $id has a capacity but no group',
        );
        expect(
          ConcordeFuelSchematic.tankPositions.containsKey(id),
          isTrue,
          reason: 'tank $id has a capacity but no schematic position',
        );
      }
    });
  });

  group('ConcordeFuelSchematic.computeTankFills', () {
    test('uses real per-tank kg when the bridge reports it', () {
      final t = _telemetry(fuelTanksKg: {'5': 8000.0});
      final chips = ConcordeFuelSchematic.computeTankFills(t);
      final tank5 = chips.firstWhere((c) => c.id == '5');
      expect(tank5.kg, closeTo(8000.0, 0.01));
      expect(tank5.pct, 73); // 8000 / 11000 = 72.7% -> rounds to 73
    });

    test('falls back to the aggregate approximation when a tank is missing', () {
      // Tanks 1/2 feed from the left aggregate channel, sent as 0-100 percent.
      final t = _telemetry(fuelLeftTank: 50.0);
      final chips = ConcordeFuelSchematic.computeTankFills(t);
      final tank1 = chips.firstWhere((c) => c.id == '1');
      expect(tank1.kg, closeTo(4800 * 0.5, 0.01));
    });

    test('main tanks blend the side channel with the center channel', () {
      final t = _telemetry(fuelLeftTank: 100.0, fuelCenterTank: 0.0);
      final chips = ConcordeFuelSchematic.computeTankFills(t);
      final tank5 = chips.firstWhere((c) => c.id == '5');
      // (100 + 0) / 2 = 50% of an 11,000 kg tank.
      expect(tank5.kg, closeTo(11000 * 0.5, 0.01));
    });

    test('trim tanks 9 & 10 read forward, 11 reads aft', () {
      final t = _telemetry(fuelTrimForward: 80.0, fuelTrimAft: 20.0);
      final chips = ConcordeFuelSchematic.computeTankFills(t);
      expect(
        chips.firstWhere((c) => c.id == '9').kg,
        closeTo(4000 * 0.8, 0.01),
      );
      expect(
        chips.firstWhere((c) => c.id == '10').kg,
        closeTo(5000 * 0.8, 0.01),
      );
      expect(
        chips.firstWhere((c) => c.id == '11').kg,
        closeTo(17480 * 0.2, 0.01),
      );
    });

    test('clamps fill to the tank capacity even if telemetry overshoots', () {
      final t = _telemetry(fuelTanksKg: {'9': 999999.0});
      final chips = ConcordeFuelSchematic.computeTankFills(t);
      final tank9 = chips.firstWhere((c) => c.id == '9');
      expect(tank9.kg, 4000.0);
      expect(tank9.pct, 100);
    });

    test('returns exactly one chip per known tank, no more, no less', () {
      final chips = ConcordeFuelSchematic.computeTankFills(_telemetry());
      expect(
        chips.map((c) => c.id).toSet(),
        ConcordeFuelSchematic.tankCapacitiesKg.keys.toSet(),
      );
    });
  });

  group('ConcordeFuelSchematic.totalFuelKg', () {
    test('sums every chip', () {
      final chips = ConcordeFuelSchematic.computeTankFills(
        _telemetry(fuelTanksKg: {'1': 1000.0, '2': 2000.0}),
      );
      final total = ConcordeFuelSchematic.totalFuelKg(chips);
      final expected = chips.fold(0.0, (s, c) => s + c.kg);
      expect(total, closeTo(expected, 0.01));
      expect(total, greaterThanOrEqualTo(3000.0));
    });

    test('an empty chip list totals to zero', () {
      expect(ConcordeFuelSchematic.totalFuelKg(const []), 0.0);
    });
  });

  group('ConcordeFuelSchematic.landscapeFraction', () {
    test(
      'rotates schematic-space percent into landscape fractional coords',
      () {
        // Nose-up x=0 (far left / wing tip) should land at the bottom (fy=1)
        // once rotated to nose-left landscape; y=0 (nose) should land at fx=0.
        final f = ConcordeFuelSchematic.landscapeFraction(0.0, 0.0);
        expect(f.fx, 0.0);
        expect(f.fy, 1.0);
      },
    );

    test(
      'center of the schematic maps to the center of the landscape frame',
      () {
        final f = ConcordeFuelSchematic.landscapeFraction(50.0, 50.0);
        expect(f.fx, closeTo(0.5, 0.001));
        expect(f.fy, closeTo(0.5, 0.001));
      },
    );
  });
}
