import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/screens/tabs/flight_planner_tab.dart';
import 'test_harness.dart';

void main() {
  group('FlightPlannerTab', () {
    testWidgets('renders all three cards without throwing', (tester) async {
      await pumpScrollableScreen(tester, const FlightPlannerTab());

      expect(tester.takeException(), isNull);
      expect(find.text('FLIGHT PLAN'), findsOneWidget);
      expect(find.text('CRUISE & FUEL MANAGEMENT'), findsOneWidget);
      expect(find.text('PERFORMANCE CALCULATOR'), findsOneWidget);
      // Shared footer, confirms the tab renders end-to-end.
      expect(find.text('VIEW CHANGELOG'), findsOneWidget);
      expect(find.text('JOIN DISCORD'), findsOneWidget);
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
