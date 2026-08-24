import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/services/airport_database_service.dart';

void main() {
  // Exercises the real startup path: no disk cache exists in a test
  // environment (path_provider is unmocked, so that lookup fails and is
  // swallowed), so this loads and parses the bundled
  // assets/airport_db.json.gz exactly like a first-ever app launch would.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AirportDatabaseService', () {
    test(
      'loads the bundled offline airport database on first launch',
      () async {
        final service = AirportDatabaseService();
        await service.initialize();

        expect(service.airports, isNotEmpty);
        expect(
          service.airports.length,
          greaterThan(1000),
          reason:
              'the bundled DB should have thousands of airports, not a handful',
        );
      },
    );

    test('parses a well-known airport with sane fields', () async {
      final service = AirportDatabaseService();
      await service.initialize();

      final egll = service.airports['EGLL'];
      expect(
        egll,
        isNotNull,
        reason: 'London Heathrow should be in the bundled DB',
      );
      expect(egll!.lat, closeTo(51.47, 0.5));
      expect(egll.lon, closeTo(-0.46, 0.5));
      expect(egll.runways, isNotEmpty);
      for (final rw in egll.runways) {
        expect(rw.lengthM, greaterThan(0));
        expect(rw.heading, inInclusiveRange(0, 360));
      }
    });

    test('every airport key is a valid 4-character ICAO code', () async {
      final service = AirportDatabaseService();
      await service.initialize();

      for (final icao in service.airports.keys) {
        expect(
          icao.length,
          4,
          reason: '"$icao" is not a 4-character ICAO code',
        );
        expect(
          icao,
          icao.toUpperCase(),
          reason: '"$icao" should be stored uppercase',
        );
      }
    });

    test('lat/lon are within valid Earth coordinate ranges', () async {
      final service = AirportDatabaseService();
      await service.initialize();

      for (final a in service.airports.values) {
        expect(
          a.lat,
          inInclusiveRange(-90, 90),
          reason: '${a.icao} has an invalid latitude',
        );
        expect(
          a.lon,
          inInclusiveRange(-180, 180),
          reason: '${a.icao} has an invalid longitude',
        );
      }
    });
  });
}
