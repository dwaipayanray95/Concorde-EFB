import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/services/flight_plan_import_service.dart';

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
  });
}
