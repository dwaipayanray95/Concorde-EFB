import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/models/concorde_models.dart';
import 'package:concorde_efb/core/metar_parser.dart';

void main() {
  group('parseWind', () {
    test('parses standard wind group in knots', () {
      final w = MetarParser.parseWind('EGLL 141150Z 24010KT 9999 SCT030 12/08 Q1013');
      expect(w.windDirDeg, 240);
      expect(w.windSpeedKt, 10);
      expect(w.windGustKt, isNull);
    });

    test('parses gusting wind', () {
      final w = MetarParser.parseWind('KJFK 141151Z 28018G28KT 10SM FEW250 25/12 A2992');
      expect(w.windDirDeg, 280);
      expect(w.windSpeedKt, 18);
      expect(w.windGustKt, 28);
    });

    test('parses variable wind as null direction', () {
      final w = MetarParser.parseWind('LFPG 141200Z VRB03KT CAVOK 15/10 Q1018');
      expect(w.windDirDeg, isNull);
      expect(w.windSpeedKt, 3);
    });

    test('converts MPS to knots', () {
      final w = MetarParser.parseWind('UUEE 141200Z 22005MPS 9999 OVC020 05/03 Q1005');
      expect(w.windSpeedKt, closeTo(5 * 1.94384, 0.01));
    });
  });

  group('parseQnh', () {
    test('parses hPa', () {
      final q = MetarParser.parseQnh('EGLL 141150Z 24010KT 9999 12/08 Q1013');
      expect(q!.unit, 'hPa');
      expect(q.value, 1013);
    });

    test('parses inHg', () {
      final q = MetarParser.parseQnh('KJFK 141151Z 28018KT 10SM 25/12 A2992');
      expect(q!.unit, 'inHg');
      expect(q.value, closeTo(29.92, 0.001));
    });
  });

  group('parseTempC', () {
    test('parses positive temperature', () {
      expect(MetarParser.parseTempC('EGLL 141150Z 24010KT 9999 12/08 Q1013'), 12);
    });

    test('parses negative temperature', () {
      expect(MetarParser.parseTempC('BIKF 141200Z 36015KT 9999 M02/M05 Q0998'), -2);
    });
  });

  group('parseVisibilityKm', () {
    test('parses metric visibility', () {
      expect(MetarParser.parseVisibilityKm('EGLL 141150Z 24010KT 0800 FG 08/08 Q1013'), 0.8);
    });

    test('9999 means 10km or more', () {
      expect(MetarParser.parseVisibilityKm('EGLL 141150Z 24010KT 9999 12/08 Q1013'), 10.0);
    });

    test('CAVOK means 10km or more', () {
      expect(MetarParser.parseVisibilityKm('LFPG 141200Z VRB03KT CAVOK 15/10 Q1018'), 10.0);
    });

    test('does not mistake wind or QNH groups for visibility', () {
      // No visibility group at all: 5-digit wind, 6-digit time, Q-prefixed QNH.
      expect(MetarParser.parseVisibilityKm('XXXX 141150Z 24010KT 12/08 Q1013'), isNull);
    });

    test('parses whole statute miles', () {
      expect(
        MetarParser.parseVisibilityKm('KJFK 141151Z 28018KT 10SM FEW250 25/12 A2992'),
        closeTo(16.09, 0.01),
      );
    });

    test('parses fractional statute miles', () {
      expect(
        MetarParser.parseVisibilityKm('KJFK 141151Z 28004KT 1/2SM FG VV002 12/12 A2992'),
        closeTo(0.5 * 1.60934, 0.01),
      );
    });

    test('parses mixed whole-and-fraction statute miles', () {
      expect(
        MetarParser.parseVisibilityKm('KJFK 141151Z 28004KT 1 1/2SM BR OVC004 12/12 A2992'),
        closeTo(1.5 * 1.60934, 0.01),
      );
    });

    test('parses "less than" fractional statute miles', () {
      expect(
        MetarParser.parseVisibilityKm('KJFK 141151Z 00000KT M1/4SM FG VV001 12/12 A2992'),
        closeTo(0.25 * 1.60934, 0.01),
      );
    });
  });

  group('parseCeilingFt', () {
    test('finds lowest broken/overcast layer', () {
      expect(
        MetarParser.parseCeilingFt('EGLL 141150Z 24010KT 9999 SCT008 BKN014 OVC030 12/08 Q1013'),
        1400,
      );
    });

    test('vertical visibility counts as ceiling', () {
      expect(MetarParser.parseCeilingFt('KJFK 141151Z 00000KT M1/4SM FG VV001 12/12 A2992'), 100);
    });

    test('scattered and few are not a ceiling', () {
      expect(MetarParser.parseCeilingFt('EGLL 141150Z 24010KT 9999 FEW020 SCT045 12/08 Q1013'), isNull);
    });
  });

  group('parseFlightCategory', () {
    test('clear day is VFR', () {
      expect(MetarParser.parseFlightCategory('LFPG 141200Z VRB03KT CAVOK 15/10 Q1018'), 'VFR');
    });

    test('good visibility but low ceiling is IFR', () {
      expect(
        MetarParser.parseFlightCategory('EGLL 141150Z 24010KT 9999 BKN008 12/08 Q1013'),
        'IFR',
      );
    });

    test('half-mile fog is LIFR', () {
      expect(
        MetarParser.parseFlightCategory('KJFK 141151Z 28004KT 1/2SM FG VV002 12/12 A2992'),
        'LIFR',
      );
    });

    test('marginal ceiling is MVFR', () {
      expect(
        MetarParser.parseFlightCategory('EGLL 141150Z 24010KT 9999 BKN025 12/08 Q1013'),
        'MVFR',
      );
    });
  });

  group('calculateComponents', () {
    test('direct headwind', () {
      final c = MetarParser.calculateComponents(270, 20, 270);
      expect(c.headwindKt, closeTo(20, 0.1));
      expect(c.crosswindKt, closeTo(0, 0.1));
    });

    test('direct crosswind from the right', () {
      final c = MetarParser.calculateComponents(360, 15, 270);
      expect(c.headwindKt, closeTo(0, 0.1));
      expect(c.crosswindKt, closeTo(15, 0.1));
      expect(c.crosswindDir, 'R');
    });

    test('tailwind is negative headwind', () {
      final c = MetarParser.calculateComponents(90, 10, 270);
      expect(c.headwindKt, closeTo(-10, 0.1));
    });
  });

  group('MetarParser weather / runway condition / age', () {
    test('summary distinguishes overcast from broken and lists weather', () {
      expect(
        MetarParser.parseWeatherSummary(
          'EGLL 141150Z 24010KT 6000 -RA OVC008 12/08 Q1013',
        ),
        'LIGHT RAIN · OVERCAST 800 FT',
      );
      expect(
        MetarParser.parseWeatherSummary(
          'EGLL 141150Z 24010KT 9999 FEW020 BKN045 12/08 Q1013',
        ),
        'BROKEN 4500 FT',
      );
      expect(
        MetarParser.parseWeatherSummary('LFPG 141200Z VRB03KT CAVOK 15/10 Q1018'),
        'CAVOK',
      );
      expect(
        MetarParser.parseWeatherSummary(
          'KJFK 141151Z 28018G28KT 3SM +TSRA BKN025CB 25/22 A2992',
        ),
        'HEAVY THUNDERSTORM RAIN · BROKEN 2500 FT · CB',
      );
    });

    test('station identifier is never read as weather', () {
      expect(
        MetarParser.parsePresentWeather('SARA 141150Z 24010KT 9999 12/08 Q1013'),
        isEmpty,
      );
    });

    test('runway condition inferred from weather', () {
      expect(
        MetarParser.inferRunwayCondition('EGLL 141150Z 24010KT 9999 FEW030 12/08 Q1013'),
        RunwayCondition.dry,
      );
      expect(
        MetarParser.inferRunwayCondition('EGLL 141150Z 24010KT 6000 -DZ OVC008 12/08 Q1013'),
        RunwayCondition.wet,
      );
      expect(
        MetarParser.inferRunwayCondition('EGLL 141150Z 24010KT 9999 FEW030 12/08 Q1013 RERA'),
        RunwayCondition.wet,
      );
      expect(
        MetarParser.inferRunwayCondition('CYUL 141200Z 05012KT 1SM -SN OVC010 M05/M07 A2992'),
        RunwayCondition.contaminated,
      );
      expect(
        MetarParser.inferRunwayCondition('EGLL 141150Z 24010KT 2000 FZDZ OVC004 M01/M02 Q1013'),
        RunwayCondition.contaminated,
      );
    });

    test('observation age in minutes', () {
      final now = DateTime.utc(2026, 10, 14, 12, 30);
      expect(
        MetarParser.metarAgeMinutes('EGLL 141150Z 24010KT 9999 12/08 Q1013', now: now),
        40,
      );
      // Day 30 seen on the 1st belongs to the previous month.
      expect(
        MetarParser.parseObservationTime(
          'EGLL 302350Z 24010KT 9999 12/08 Q1013',
          now: DateTime.utc(2026, 10, 1, 0, 10),
        ),
        DateTime.utc(2026, 9, 30, 23, 50),
      );
    });
  });
}
