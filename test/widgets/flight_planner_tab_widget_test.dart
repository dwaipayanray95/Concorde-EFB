import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/screens/tabs/flight_planner_tab.dart';
import 'test_harness.dart';

void main() {
  group('FlightPlannerTab', () {
    testWidgets('renders cards across sub-tabs without throwing', (tester) async {
      await pumpScrollableScreen(tester, const FlightPlannerTab());

      expect(tester.takeException(), isNull);
      // Route & Fuel sub-tab is active by default
      expect(find.text('FLIGHT PLAN'), findsOneWidget);
      expect(find.text('CRUISE & FUEL MANAGEMENT'), findsOneWidget);
      expect(find.text('VIEW CHANGELOG'), findsOneWidget);
      expect(find.text('JOIN DISCORD'), findsOneWidget);

      // Switch to Performance Calculator sub-tab
      await tester.tap(find.text('PERFORMANCE CALCULATOR'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DEPARTURE / TAKEOFF'), findsOneWidget);
      expect(find.text('ARRIVAL / LANDING'), findsOneWidget);
    });

    testWidgets('shows the default departure/arrival ICAOs', (tester) async {
      await pumpScrollableScreen(tester, const FlightPlannerTab());

      expect(tester.takeException(), isNull);
      // departureIcaoProvider / arrivalIcaoProvider defaults.
      expect(find.textContaining('EGLL'), findsWidgets);
      expect(find.textContaining('KJFK'), findsWidgets);
    });

    testWidgets(
      'stays stable a moment after first paint (async providers settle)',
      (tester) async {
        await pumpScrollableScreen(tester, const FlightPlannerTab());
        await tester.pump(const Duration(milliseconds: 500));

        expect(tester.takeException(), isNull);
      },
    );
  });
}
