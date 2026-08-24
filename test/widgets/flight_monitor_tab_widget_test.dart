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
      expect(find.text('VIEW CHANGELOG'), findsOneWidget);
      expect(find.text('JOIN DISCORD'), findsOneWidget);
    });

    testWidgets('stays stable a moment after first paint', (tester) async {
      await pumpScrollableScreen(tester, const FlightMonitorTab());
      await tester.pump(const Duration(milliseconds: 500));

      expect(tester.takeException(), isNull);
    });
  });
}
