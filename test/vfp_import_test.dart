import 'package:concorde_efb/services/flight_plan_import_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const vfp = '''<?xml version="1.0" encoding="utf-8"?>
<FlightPlan xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" FlightType="IFR" Equipment="SDFGHIRWY" CruiseAltitude="57000" CruiseSpeed="1150" DepartureAirport="vohs" DestinationAirport="YPDN" AlternateAirport="YBTL" Route="DCT  ALPOR L301 DCT" Remarks="" IsHeavy="true" />''';

  test('parses vPilot .vfp attributes', () {
    final p = FlightPlanImportService.parseAnyXml(vfp)!;
    expect(p.departureIcao, 'VOHS');
    expect(p.arrivalIcao, 'YPDN');
    expect(p.alternateIcao, 'YBTL');
    expect(p.route, 'DCT ALPOR L301 DCT');
    expect(p.cruiseAltFt, 57000);
  });

  test('decodes UTF-16 LE and strips the UTF-8 BOM', () {
    final le = <int>[0xFF, 0xFE];
    for (final c in 'AB'.codeUnits) {
      le.addAll([c, 0]);
    }
    expect(FlightPlanImportService.decodeFile(le), 'AB');
    expect(FlightPlanImportService.decodeFile([0xEF, 0xBB, 0xBF, 0x41]), 'A');
  });

  test('reads call sign / registration / pax when present', () {
    final p = FlightPlanImportService.parseAnyXml(
      '<FlightPlan Callsign="baw1" DepartureAirport="EGLL" '
      'DestinationAirport="KJFK" Remarks="REG/G-BOAD PAX/96" />',
    )!;
    expect(p.callSign, 'BAW1');
    expect(p.registration, 'G-BOAD');
    expect(p.paxCount, 96);
  });

  test('identity is null when the file has none', () {
    final p = FlightPlanImportService.parseAnyXml(vfp)!;
    expect(p.callSign, isNull);
    expect(p.registration, isNull);
    expect(p.paxCount, isNull);
  });

  test('.pln identity tags', () {
    final p = FlightPlanImportService.parsePln(
      '<FlightPlan.FlightPlan><ATCCallsign>AIC2</ATCCallsign>'
      '<DepartureID>EGLL</DepartureID><DestinationID>KJFK</DestinationID>'
      '</FlightPlan.FlightPlan>',
    )!;
    expect(p.callSign, 'AIC2');
  });
}
