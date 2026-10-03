import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/services/flight_plan_import_service.dart';
import 'package:concorde_efb/services/simbrief_service.dart';

void main() {
  group('FlightPlanImportService', () {
    const samplePln = '''<?xml version="1.0" encoding="UTF-8"?>
<SimBase.Document>
    <FlightPlan.FlightPlan>
        <DepartureID>OMDB</DepartureID>
        <DestinationID>EGCC</DestinationID>
        <Title>OMDB - EGCC</Title>
        <Descr>OMDB to EGCC created by SimBrief</Descr>
        <FPType>IFR</FPType>
        <CruisingAlt>30000</CruisingAlt>
        <DepartureDetails>
            <RunwayNumberFP>30</RunwayNumberFP>
            <RunwayDesignatorFP>RIGHT</RunwayDesignatorFP>
            <DepartureFP>RIDA2F</DepartureFP>
        </DepartureDetails>
        <ATCWaypoint>
            <ATCWaypointType>Intersection</ATCWaypointType>
            <ICAO>
                <ICAORegion>OM</ICAORegion>
                <ICAOIdent>RIDAP</ICAOIdent>
            </ICAO>
        </ATCWaypoint>
        <ATCWaypoint>
            <ATCWaypointType>Intersection</ATCWaypointType>
            <ATCAirway>M557</ATCAirway>
            <ICAO>
                <ICAORegion>OM</ICAORegion>
                <ICAOIdent>OTIKI</ICAOIdent>
            </ICAO>
        </ATCWaypoint>
        <ATCWaypoint>
            <ATCWaypointType>Intersection</ATCWaypointType>
            <ATCAirway>M557</ATCAirway>
            <ICAO>
                <ICAORegion>OM</ICAORegion>
                <ICAOIdent>TOTKU</ICAOIdent>
            </ICAO>
        </ATCWaypoint>
        <ATCWaypoint>
            <ATCWaypointType>Intersection</ATCWaypointType>
            <ATCAirway>L602</ATCAirway>
            <ICAO>
                <ICAORegion>OB</ICAORegion>
                <ICAOIdent>VEDOM</ICAOIdent>
            </ICAO>
        </ATCWaypoint>
        <ArrivalDetails>
            <RunwayNumberFP>23</RunwayNumberFP>
            <RunwayDesignatorFP>RIGHT</RunwayDesignatorFP>
            <ArrivalFP>ELVO1M</ArrivalFP>
        </ArrivalDetails>
    </FlightPlan.FlightPlan>
</SimBase.Document>''';

    test('parses MSFS PLN with nested ICAOIdent and Departure/Arrival runways', () {
      final plan = FlightPlanImportService.parsePln(samplePln);
      expect(plan, isNotNull);
      expect(plan!.departureIcao, 'OMDB');
      expect(plan.arrivalIcao, 'EGCC');
      expect(plan.departureRunway, '30R');
      expect(plan.arrivalRunway, '23R');
      expect(plan.route, 'RIDAP M557 OTIKI TOTKU L602 VEDOM');
    });

    test('parses attribute-style ATCWaypoint id', () {
      const attrPln = '''<?xml version="1.0" encoding="UTF-8"?>
<SimBase.Document>
    <FlightPlan.FlightPlan>
        <DepartureID>EGLL</DepartureID>
        <DestinationID>KJFK</DestinationID>
        <ATCWaypoint id="EGLL" />
        <ATCWaypoint id="CPT" />
        <ATCWaypoint id="KENET" />
        <ATCWaypoint id="KJFK" />
    </FlightPlan.FlightPlan>
</SimBase.Document>''';

      final plan = FlightPlanImportService.parsePln(attrPln);
      expect(plan, isNotNull);
      expect(plan!.departureIcao, 'EGLL');
      expect(plan.arrivalIcao, 'KJFK');
      expect(plan.route, 'CPT KENET');
    });

    test('parses manually pasted route with ICAO and runway tokens', () {
      const manualRoute = 'OMDB/12L OMDB/30R RIDAP M557 OTIKI TOTKU GODKI RALMI EGCC/23R EGCC/05L';
      final plan = FlightPlanImportService.parseManualRoute(manualRoute);

      expect(plan.departureIcao, 'OMDB');
      expect(plan.departureRunway, '30R');
      expect(plan.arrivalIcao, 'EGCC');
      expect(plan.arrivalRunway, '23R');
      expect(plan.route, 'RIDAP M557 OTIKI TOTKU GODKI RALMI');
    });

    test('parses standard space-separated manual route tokens', () {
      const manualRoute = 'OMDB 30R RIDAP M557 OTIKI EGCC 23R';
      final plan = FlightPlanImportService.parseManualRoute(manualRoute);

      expect(plan.departureIcao, 'OMDB');
      expect(plan.departureRunway, '30R');
      expect(plan.arrivalIcao, 'EGCC');
      expect(plan.arrivalRunway, '23R');
      expect(plan.route, 'RIDAP M557 OTIKI');
    });
    test('reads fix coordinates from WorldPosition', () {
      const pln = '''<SimBase.Document><FlightPlan.FlightPlan>
        <DepartureID>EGLL</DepartureID>
        <DestinationID>KJFK</DestinationID>
        <ATCWaypoint id="EGLL"><WorldPosition>N51° 28' 39.00",W0° 27' 41.00",+000083.00</WorldPosition></ATCWaypoint>
        <ATCWaypoint id="CPT"><ATCWaypointType>VOR</ATCWaypointType><WorldPosition>N51° 29' 31.20",W1° 13' 10.00",+000000.00</WorldPosition></ATCWaypoint>
        <ATCWaypoint id="NOFIX"><ATCWaypointType>Intersection</ATCWaypointType></ATCWaypoint>
        <ATCWaypoint id="BOS"><WorldPosition>N42° 21' 26.00",W70° 59' 22.00",+000000.00</WorldPosition></ATCWaypoint>
        <ATCWaypoint id="KJFK"><WorldPosition>N40° 38' 23.00",W73° 46' 44.00",+000013.00</WorldPosition></ATCWaypoint>
      </FlightPlan.FlightPlan></SimBase.Document>''';
      final plan = FlightPlanImportService.parsePln(pln)!;
      // Airports themselves and fixes without a position are excluded.
      expect(plan.fixes.map((f) => f.ident), ['CPT', 'BOS']);
      expect(plan.fixes.first.lat, closeTo(51.492, 0.001));
      expect(plan.fixes.first.lon, closeTo(-1.2194, 0.001));
      expect(plan.fixes.last.lat, closeTo(42.357, 0.001));
    });

    test('SimBrief navlog fixes (list or single object)', () {
      final ofp = <String, dynamic>{
        'origin': {'icao_code': 'EGLL'},
        'destination': {'icao_code': 'KJFK'},
        'navlog': {
          'fix': [
            {'ident': 'CPT', 'pos_lat': '51.492', 'pos_long': '-1.219'},
            {'ident': 'BAD', 'pos_lat': '', 'pos_long': 'x'},
            {'ident': 'KJFK', 'pos_lat': '40.6', 'pos_long': '-73.8'},
          ],
        },
      };
      final fixes = SimBriefService.navlogFixes(ofp);
      expect(fixes.map((f) => f.ident), ['CPT']);
      ofp['navlog'] = {
        'fix': {'ident': 'CPT', 'pos_lat': '51.492', 'pos_long': '-1.219'},
      };
      expect(SimBriefService.navlogFixes(ofp).length, 1);
    });
  });
}
