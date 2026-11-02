import 'package:concorde_efb/features/logbook/data/flight_log.dart';
import 'package:concorde_efb/features/logbook/presentation/logbook_providers.dart';
import 'package:concorde_efb/features/logbook/presentation/logbook_tab.dart';
import 'package:concorde_efb/core/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

class _FakeLogbook extends LogbookNotifier {
  final List<FlightLog> logs;
  _FakeLogbook(this.logs);
  @override
  Future<List<FlightLog>> build() async => logs;
  @override
  Future<void> upsert(FlightLog log) async {}
  @override
  Future<void> delete(String id) async => state = AsyncData([
    for (final l in logs)
      if (l.id != id) l,
  ]);
}

FlightLog _log(String id, int day, double fpm, {bool done = true}) => FlightLog(
  id: id,
  updatedAt: DateTime.utc(2026, 5, day),
  callSign: 'BAW$day',
  plannedDep: 'EGLL',
  plannedArr: 'KJFK',
  blockOut: DateTime.utc(2026, 5, day, 10),
  takeoff: DateTime.utc(2026, 5, day, 10, 15),
  touchdown: done ? DateTime.utc(2026, 5, day, 13, 30) : null,
  blockIn: done ? DateTime.utc(2026, 5, day, 13, 40) : null,
  touchdownFpm: done ? fpm : null,
  touchdownG: done ? 1.2 : null,
  supersonicSec: 7200,
  fuelBlockOutKg: 95000,
  fuelTakeoffKg: 93000,
  fuelLandingKg: 20000,
  fuelBlockInKg: 19800,
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('shows totals, rows and opens detail', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final logs = [_log('a', 2, 100), _log('b', 1, 300)];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [logbookProvider.overrideWith(() => _FakeLogbook(logs))],
        child: MaterialApp(
          theme: ThemeData(extensions: [AppColors.dark]),
          home: const Scaffold(body: LogbookTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FLIGHTS'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('7:20'), findsOneWidget); // 2 x 3:40 block
    expect(find.text('200 FPM'), findsOneWidget); // average
    expect(find.text('BAW2'), findsOneWidget);
    expect(find.text('EGLL → KJFK'), findsNWidgets(2));

    await tester.tap(find.text('BAW2'));
    await tester.pumpAndSettle();
    expect(find.text('BAW2 · EGLL → KJFK'), findsOneWidget);
    expect(find.text('OOOI (ZULU)'), findsOneWidget);
    expect(find.text('BUTTER'), findsOneWidget);
  });
}
