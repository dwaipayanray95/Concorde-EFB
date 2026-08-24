import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/screens/home_screen.dart';
import 'test_harness.dart';

void main() {
  group('HomeScreen', () {
    testWidgets('shows the loading state before the airport DB resolves', (
      tester,
    ) async {
      await pumpFullScreen(tester, const HomeScreen());
      // First frame only -- airportDbProvider is still loading.
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('LOADING AIRPORT DATABASE...'), findsOneWidget);
    });

    // HomeScreen gates its whole tab shell behind airportDbProvider, which
    // resolves via compute() (a real isolate). That reliably hangs inside
    // testWidgets()'s zone in this environment (confirmed: the exact same
    // AirportDatabaseService logic resolves in well under a second under a
    // plain test() in airport_database_service_test.dart, but times out
    // after 10+ real seconds here even via tester.runAsync). Rather than
    // fight that zone interaction, the tab shell itself (ChecklistsTab,
    // FlightPlannerTab, FlightMonitorTab) is exercised directly in its own
    // widget test file -- better granularity anyway, since those don't need
    // the airport DB to be present just to render.
  });
}
