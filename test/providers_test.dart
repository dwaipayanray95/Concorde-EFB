import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:concorde_efb/providers/efb_providers.dart';
import 'package:concorde_efb/core/concorde_constants.dart';
import 'package:concorde_efb/models/concorde_models.dart';
import 'package:concorde_efb/models/airport.dart';

void main() {
  group('weightsProvider', () {
    test('ZFW = OEW + pax; TOW = ZFW + fuel on board - taxi fuel', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(100);
      final w = container.read(weightsProvider);
      final taxi = container.read(taxiFuelProvider);

      final expectedPax = 100 * ConcordeConstants.weights.paxMassKg;
      expect(w.pax, closeTo(expectedPax, 0.01));
      expect(
        w.zfw,
        closeTo(ConcordeConstants.weights.oewKg + expectedPax, 0.01),
      );
      expect(w.ramp, closeTo(w.zfw + w.fuelOnBoard, 0.01));
      expect(w.tow, closeTo(w.ramp - taxi, 0.01));
    });

    test('LW is TOW minus trip fuel, never below ZFW', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final w = container.read(weightsProvider);
      final trip = container.read(missionProfileProvider).tripKg;
      expect(w.lw, closeTo(w.tow - trip, 0.01));
      expect(w.lw, greaterThanOrEqualTo(w.zfw));
    });

    test('fuel on board is capped at the aircraft fuel capacity', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(extraFuelProvider.notifier).set(2000000);

      final w = container.read(weightsProvider);
      expect(w.fuelOnBoard, ConcordeConstants.weights.fuelCapacityKg);
      expect(
        w.plannedFuel,
        greaterThan(ConcordeConstants.weights.fuelCapacityKg),
      );
      expect(w.overCapacity, isTrue);
      expect(
        w.ramp,
        closeTo(w.zfw + ConcordeConstants.weights.fuelCapacityKg, 0.01),
      );
    });

    test('extra passengers increase TOW', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(50);
      final lightTow = container.read(weightsProvider).tow;

      container.read(paxCountProvider.notifier).set(100);
      final heavyTow = container.read(weightsProvider).tow;

      expect(heavyTow, greaterThan(lightTow));
    });

    test('full pax + full fuel stays under MTOW', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(100);
      container.read(extraFuelProvider.notifier).set(2000000);
      expect(
        container.read(weightsProvider).ramp,
        lessThan(ConcordeConstants.weights.mtowKg),
      );
    });
  });

  group('fuelEnduranceProvider', () {
    test('a plan that fits in the tanks has sufficient endurance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(fuelEnduranceProvider).sufficient, isTrue);
    });

    test('a plan capped by tank capacity is flagged insufficient', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(plannedDistanceProvider.notifier).set(3900);
      container.read(finalReserveFuelProvider.notifier).set(15000);
      expect(container.read(weightsProvider).overCapacity, isTrue);
      expect(container.read(fuelEnduranceProvider).sufficient, isFalse);
    });
  });

  group('takeoffSpeedsProvider / landingSpeedsProvider', () {
    test('ordering V1 <= VR < V2 and VAPP above VREF', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final takeoff = container.read(takeoffSpeedsProvider);
      final landing = container.read(landingSpeedsProvider);

      expect(takeoff.v1, lessThanOrEqualTo(takeoff.vr));
      expect(takeoff.vr, lessThan(takeoff.v2));
      expect(landing.vapp - landing.vref, inInclusiveRange(5, 20));
    });

    test('a heavier aircraft needs faster takeoff speeds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(20);
      final lightVr = container.read(takeoffSpeedsProvider).vr;

      container.read(paxCountProvider.notifier).set(100);
      container.read(extraFuelProvider.notifier).set(10000);
      final heavyVr = container.read(takeoffSpeedsProvider).vr;

      expect(heavyVr, greaterThan(lightVr));
    });
  });

  group('alternateStatusProvider', () {
    test('empty alternate is flagged missing', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(alternateIcaoProvider.notifier).set('');
      expect(container.read(alternateStatusProvider), AlternateStatus.missing);
    });

    test('alternate equal to arrival is flagged', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(alternateIcaoProvider.notifier).set('KJFK');
      expect(
        container.read(alternateStatusProvider),
        AlternateStatus.sameAsArrival,
      );
    });
  });

  group('CruiseFLNotifier', () {
    test('defaults to a valid non-RVSM level even with direction unknown', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final fl = container.read(cruiseFLProvider);
      // Airport DB hasn't resolved in a bare ProviderContainer, so direction
      // is null -- the notifier must still snap eagerly to a valid level
      // rather than leaving the raw unsnapped default (590) untouched in a
      // state that silently assumed a direction.
      const eastbound = {410, 450, 490, 530, 570};
      const westbound = {430, 470, 510, 550, 590};
      expect({...eastbound, ...westbound}.contains(fl.toInt()), isTrue);
    });

    test('set() re-snaps to the direction-specific table', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(cruiseFLProvider.notifier).set(432, 'W');
      // Nearest westbound level to 432 is 430.
      expect(container.read(cruiseFLProvider), 430.0);

      container.read(cruiseFLProvider.notifier).set(432, 'E');
      // Nearest eastbound level to 432 is 450 (410 is 22 away, 450 is 18 away).
      expect(container.read(cruiseFLProvider), 450.0);
    });
  });

  group('ChecklistNotifier', () {
    test('toggle only flips the requested item', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(checklistProvider.notifier);

      notifier.toggle('cd_bat');
      expect(container.read(checklistProvider)['cd_bat'], isTrue);
      expect(container.read(checklistProvider)['cd_gnd_pwr'], isNot(isTrue));

      notifier.toggle('cd_bat');
      expect(container.read(checklistProvider)['cd_bat'], isFalse);
    });

    test('resetPhase only clears the given ids, leaving others untouched', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(checklistProvider.notifier);

      notifier.toggle('cd_bat');
      notifier.toggle('bs_beacon');
      notifier.resetPhase(['cd_bat']);

      final state = container.read(checklistProvider);
      expect(state['cd_bat'], isFalse);
      expect(state['bs_beacon'], isTrue);
    });

    test('resetAll clears every item', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(checklistProvider.notifier);

      notifier.toggle('cd_bat');
      notifier.toggle('bs_beacon');
      notifier.resetAll();

      expect(container.read(checklistProvider), isEmpty);
    });
  });

  group('dispatchSummaryProvider', () {
    test('an over-capacity plan is NO-GO', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(extraFuelProvider.notifier).set(200000);
      final d = container.read(dispatchSummaryProvider);
      expect(d.isGo, isFalse);
      expect(d.noGo.any((s) => s.contains('tank capacity')), isTrue);
    });

    test('no alternate is a caution, not a NO-GO reason', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(alternateIcaoProvider.notifier).set('');
      final d = container.read(dispatchSummaryProvider);
      expect(d.cautions, contains('No alternate'));
      expect(d.noGo.any((s) => s.contains('lternate')), isFalse);
    });
  });

  group('bestRunwayId', () {
    final jfk = Airport(
      icao: 'KJFK',
      name: 'JFK',
      lat: 40.64,
      lon: -73.78,
      runways: [
        Runway(id: '13R', heading: 122, lengthM: 4423),
        Runway(id: '31L', heading: 302, lengthM: 3460),
        Runway(id: '04L', heading: 31, lengthM: 3682),
      ],
    );

    test('no wind -> longest runway', () {
      expect(bestRunwayId(jfk, ''), '13R');
    });

    test('avoids a tailwind runway even if it is the longest', () {
      expect(
        bestRunwayId(jfk, 'KJFK 031151Z 31015G24KT 10SM BKN015 18/11 A3002'),
        '31L',
      );
    });

    test('every runway with tailwind -> least tailwind', () {
      final one = Airport(
        icao: 'XXXX',
        name: 'x',
        lat: 0,
        lon: 0,
        runways: [
          Runway(id: '09', heading: 90, lengthM: 3000),
          Runway(id: '18', heading: 180, lengthM: 3500),
        ],
      );
      // Wind from 300: tailwind on 09 (~15) and 18 (~13 kt).
      expect(bestRunwayId(one, 'XXXX 031151Z 30026KT 9999 18/11 Q1013'), '18');
    });
  });
}

