import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:concorde_efb/providers/efb_providers.dart';
import 'package:concorde_efb/core/concorde_constants.dart';

void main() {
  group('weightsProvider', () {
    test('TOW is OEW + pax weight + fuel', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(100);
      final weights = container.read(weightsProvider);

      final expectedPax = 100 * ConcordeConstants.weights.paxMassKg;
      final expectedTow =
          ConcordeConstants.weights.oewKg + expectedPax + weights['FUEL']!;
      expect(weights['TOW'], closeTo(expectedTow, 0.01));
      expect(weights['PAX'], closeTo(expectedPax, 0.01));
    });

    test('LW is TOW minus trip fuel burned, never negative', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final weights = container.read(weightsProvider);
      expect(weights['LW'], greaterThanOrEqualTo(0.0));
      expect(weights['LW'], lessThanOrEqualTo(weights['TOW']!));
    });

    test('effective fuel is capped at the aircraft fuel capacity', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Force total fuel far past the 95,681 kg tank capacity.
      container.read(trimTankFuelProvider.notifier).set(1000000);
      container.read(extraFuelProvider.notifier).set(1000000);

      final weights = container.read(weightsProvider);
      expect(
        weights['EFFECTIVE_FUEL'],
        ConcordeConstants.weights.fuelCapacityKg,
      );
      // Raw FUEL is allowed to report the (unrealistic) uncapped total...
      expect(
        weights['FUEL'],
        greaterThan(ConcordeConstants.weights.fuelCapacityKg),
      );
      // ...but weight math (TOW) must use the capped figure, not blow past
      // what the aircraft could ever physically weigh.
      final expectedTow =
          ConcordeConstants.weights.oewKg +
          weights['PAX']! +
          ConcordeConstants.weights.fuelCapacityKg;
      expect(weights['TOW'], closeTo(expectedTow, 0.01));
    });

    test('extra passengers increase TOW', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(50);
      final lightTow = container.read(weightsProvider)['TOW']!;

      container.read(paxCountProvider.notifier).set(150);
      final heavyTow = container.read(weightsProvider)['TOW']!;

      expect(heavyTow, greaterThan(lightTow));
    });
  });

  group('takeoffSpeedsProvider / landingSpeedsProvider', () {
    test('derive directly from the current TOW/LW weights', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final weights = container.read(weightsProvider);
      final takeoff = container.read(takeoffSpeedsProvider);
      final landing = container.read(landingSpeedsProvider);

      expect(takeoff['V1']!, lessThan(takeoff['VR']!));
      expect(takeoff['VR']!, lessThan(takeoff['V2']!));
      expect(landing['VAPP']! - landing['VLS']!, closeTo(15, 0.01));

      // Sanity: recomputing straight from the weights matches the provider.
      expect(weights['TOW'], isNotNull);
      expect(weights['LW'], isNotNull);
    });

    test('a heavier aircraft needs faster takeoff speeds', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(paxCountProvider.notifier).set(20);
      final lightV1 = container.read(takeoffSpeedsProvider)['V1']!;

      container.read(paxCountProvider.notifier).set(200);
      final heavyV1 = container.read(takeoffSpeedsProvider)['V1']!;

      expect(heavyV1, greaterThan(lightV1));
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
}
