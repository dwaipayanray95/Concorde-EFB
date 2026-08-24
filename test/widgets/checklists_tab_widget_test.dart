import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/screens/tabs/checklists_tab.dart';
import 'test_harness.dart';

void main() {
  group('ChecklistsTab', () {
    testWidgets('renders the default phase without overflowing or throwing', (
      tester,
    ) async {
      await pumpBoundedScreen(tester, const ChecklistsTab());

      expect(tester.takeException(), isNull);
      // Left nav phase list.
      expect(find.text('Cold & Dark Setup'), findsOneWidget);
      // Right panel header (uppercased phase name) + first checklist item.
      expect(find.text('COLD & DARK SETUP'), findsOneWidget);
      expect(find.text('BATTERY SWITCH'), findsOneWidget);
      expect(find.text('RESET PHASE'), findsOneWidget);
    });

    testWidgets('switching phases swaps the right panel content', (
      tester,
    ) async {
      await pumpBoundedScreen(tester, const ChecklistsTab());

      await tester.tap(find.text('Before Takeoff & Taxi'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      expect(find.text('BEFORE TAKEOFF & TAXI'), findsOneWidget);
      // The cold & dark items should no longer be showing.
      expect(find.text('BATTERY SWITCH'), findsNothing);
    });

    testWidgets('tapping a checklist item toggles its checked state', (
      tester,
    ) async {
      await pumpBoundedScreen(tester, const ChecklistsTab());

      // Before check: 0/N badge for the selected (first) phase.
      expect(find.textContaining('0/'), findsWidgets);

      await tester.tap(find.text('BATTERY SWITCH'));
      await tester.pump(const Duration(milliseconds: 250));

      expect(tester.takeException(), isNull);
      // At least one item is now checked, so the phase badge should read
      // "1/<total>" somewhere in the nav list.
      expect(find.textContaining('1/'), findsWidgets);
    });

    testWidgets('list scrolls internally instead of overflowing the layout', (
      tester,
    ) async {
      // Regression guard for the earlier "BOTTOM OVERFLOWED BY 364 PIXELS"
      // bug: constrain to a short viewport and make sure Flutter doesn't
      // report a RenderFlex overflow.
      tester.view.physicalSize = const Size(1400, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpBoundedScreen(tester, const ChecklistsTab());

      expect(tester.takeException(), isNull);
    });
  });
}
