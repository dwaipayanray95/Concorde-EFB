import 'package:concorde_efb/features/logbook/data/flight_log.dart';
import 'package:concorde_efb/features/logbook/presentation/widgets/acars_fuel_release.dart';
import 'package:concorde_efb/features/logbook/presentation/widgets/cg_corridor_chart.dart';
import 'package:concorde_efb/features/logbook/presentation/widgets/flight_profile_chart.dart';
import 'package:concorde_efb/features/logbook/presentation/widgets/flight_sparkline.dart';
import 'package:concorde_efb/features/logbook/presentation/widgets/runway_performance_card.dart';
import 'package:concorde_efb/core/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

FlightLog _dummyLog() => FlightLog(
      id: 'BAW001-20261116',
      updatedAt: DateTime.utc(2026, 11, 16),
      callSign: 'BAW001',
      registration: 'G-BOAC',
      plannedDep: 'EGLL',
      plannedArr: 'KJFK',
      blockOut: DateTime.utc(2026, 11, 16, 10, 14),
      takeoff: DateTime.utc(2026, 11, 16, 10, 32),
      touchdown: DateTime.utc(2026, 11, 16, 13, 46),
      blockIn: DateTime.utc(2026, 11, 16, 13, 58),
      plannedTimeH: 3.25,
      plannedTripKg: 71200,
      cruiseFl: 580,
      fuelBlockOutKg: 95200,
      fuelTakeoffKg: 93800,
      fuelLandingKg: 22350,
      fuelBlockInKg: 21800,
      finalReserveKg: 6500,
      zfwKg: 88600,
      maxMach: 2.04,
      maxAltFt: 58200,
      supersonicSec: 8200,
      distanceNm: 3150,
      touchdownFpm: 145,
      touchdownG: 1.15,
      touchdownPitch: 10.5,
      touchdownIas: 162,
      bounces: 0,
      goArounds: 0,
      track: [
        // [epochSec, lat, lon, altFt, gsKt, iasKt, vsFpm, mach, fuelKg, cgPct]
        [1794789000, 51.47, -0.45, 80, 0, 0, 0, 0.0, 93800, 53.6],
        [1794789500, 51.20, -1.50, 28000, 450, 400, 2200, 0.95, 88000, 54.5],
        [1794792000, 50.00, -25.00, 54000, 1170, 430, 80, 2.02, 52000, 58.8],
        [1794796000, 41.00, -70.00, 10000, 280, 250, -1500, 0.50, 24000, 54.0],
        [1794798000, 40.64, -73.78, 13, 140, 162, -145, 0.25, 22350, 53.8],
      ],
      perf: {
        'takeoff': {
          'rollM': 2540,
          'rollSec': 38,
          'liftoffIas': 198,
          'liftoffGs': 204,
          'reheat': 4,
          'towKg': 182400,
          'plan': {
            'icao': 'EGLL',
            'runway': '27R',
            'requiredM': 2680,
            'runwayLengthM': 3658,
          },
        },
        'landing': {
          'touchdownIas': 162,
          'rollToExitM': 2010,
          'rollToExitSec': 34,
          'plan': {
            'icao': 'KJFK',
            'runway': '31L',
            'requiredM': 2120,
            'runwayLengthM': 4470,
          },
        },
      },
    );

void main() {
  Widget wrap(Widget child) => MaterialApp(
        theme: ThemeData(extensions: [AppColors.dark]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      );

  testWidgets('FlightSparkline renders with track points without throwing',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final log = _dummyLog();
    await tester.pumpWidget(wrap(FlightSparkline(track: log.track)));
    expect(find.byType(FlightSparkline), findsOneWidget);
  });

  testWidgets('FlightProfileChart renders and handles mode switches',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final log = _dummyLog();
    await tester.pumpWidget(wrap(FlightProfileChart(log: log)));
    expect(find.text('MISSION PROFILE & TELEMETRY RECORDER'), findsOneWidget);
    expect(find.text('SECONDARY OVERLAY:'), findsOneWidget);
    expect(find.text('MACH'), findsOneWidget);
    expect(find.text('FUEL ON BOARD'), findsNWidgets(2)); // button + cell label
    expect(find.text('CG % MAC'), findsOneWidget);

    // Switch mode
    await tester.tap(find.text('CG % MAC'));
    await tester.pumpAndSettle();
    expect(find.byType(FlightProfileChart), findsOneWidget);
  });

  testWidgets('CgCorridorChart renders and displays phase CG stats',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final log = _dummyLog();
    await tester.pumpWidget(wrap(CgCorridorChart(log: log)));
    expect(find.text('CONCORDE CG FLIGHT ENVELOPE (MACH vs CG %)'), findsOneWidget);
    expect(find.text('SUBSONIC CG'), findsOneWidget);
    expect(find.text('M2.0 CRUISE CG'), findsOneWidget);
    expect(find.text('APPROACH CG'), findsOneWidget);
    expect(find.text('100% IN SAFE CORRIDOR'), findsOneWidget);
  });

  testWidgets('RunwayPerformanceCard displays takeoff and rollout sections',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final log = _dummyLog();
    await tester.pumpWidget(wrap(RunwayPerformanceCard(log: log)));
    expect(find.text('MEASURED RUNWAY PERFORMANCE vs MODEL'), findsOneWidget);
    expect(find.text('PREDICTED ROLL'), findsOneWidget);
    expect(find.text('ACTUAL ROLL'), findsOneWidget);
    expect(find.text('RATE OF DESCENT'), findsOneWidget);
    expect(find.text('ROLL TO 30 KT EXIT'), findsOneWidget);
  });

  testWidgets('AcarsFuelReleaseStrip displays dispatch breakdown',
      (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final log = _dummyLog();
    await tester.pumpWidget(wrap(AcarsFuelReleaseStrip(log: log)));
    expect(find.text('ACARS DISPATCH FUEL AUDIT'), findsOneWidget);
    expect(find.text('BLOCK OUT FUEL:'), findsOneWidget);
    expect(find.text('TAKEOFF FUEL:'), findsOneWidget);
    expect(find.text('ACTUAL TRIP BURN:'), findsOneWidget);
    expect(find.text('FINAL RESERVE MARGIN:'), findsOneWidget);
  });
}
