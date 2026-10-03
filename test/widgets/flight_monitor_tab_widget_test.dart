import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/screens/tabs/flight_monitor_tab.dart';
import 'test_harness.dart';

void main() {
  group('FlightMonitorTab', () {
    testWidgets('renders the disconnected default state without throwing', (
      tester,
    ) async {
      await pumpScrollableScreen(tester, const FlightMonitorTab());

      expect(tester.takeException(), isNull);
      // Shared footer, confirms the tab renders end-to-end.
      // Footer is now just the support card.
      expect(find.text('DONATE NOW'), findsOneWidget);
    });

    testWidgets('stays stable a moment after first paint', (tester) async {
      await pumpScrollableScreen(tester, const FlightMonitorTab());
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}
