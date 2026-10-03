import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/screens/tabs/flight_planner_tab.dart';
import 'package:concorde_efb/screens/tabs/flight_planner/performance_calculator_section.dart';
import 'package:concorde_efb/screens/widgets/app_footer.dart';
import 'test_harness.dart';

void main() {
  group('FlightPlannerTab', () {
    testWidgets('renders cards across sub-tabs without throwing', (
      tester,
    ) async {
      await pumpScrollableScreen(tester, const FlightPlannerTab());

      expect(tester.takeException(), isNull);
      // Route & Fuel sub-tab is active by default
      expect(find.text('FLIGHT PLAN'), findsOneWidget);
      expect(find.text('CRUISE & FUEL MANAGEMENT'), findsOneWidget);
      // Footer is now just the support card (desktop) / ad banner (mobile;
      // flutter_test runs as Android, where no ad loads without consent).
      expect(find.byType(AppFooter), findsOneWidget);

      // Switch to Performance Calculator sub-tab
      await tester.tap(find.text('PERFORMANCE CALCULATOR'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('DEPARTURE / TAKEOFF'), findsOneWidget);
      expect(find.text('ARRIVAL / LANDING'), findsOneWidget);

      // Runway-condition selector on both legs; switching it must not throw.
      expect(find.text('RWY COND'), findsNWidgets(2));
      await tester.tap(find.text('WET').first);
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
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

  test('METAR age is spelled out, never abbreviated', () {
    expect(formatMetarAge(1), '1 MIN');
    expect(formatMetarAge(36), '36 MINS');
    expect(formatMetarAge(60), '1 HR');
    expect(formatMetarAge(125), '2 HRS 5 MINS');
  });
}
