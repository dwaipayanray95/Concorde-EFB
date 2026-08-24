import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:concorde_efb/core/app_colors.dart';

/// Shared widget-test harness for the app's screens.
///
/// Two real things a bare `pumpWidget` would break on:
///  - ThemeModeNotifier / SimbriefUserNotifier fire off an unawaited
///    `SharedPreferences.getInstance()` from build() -- without a mock
///    value set first, that throws a MissingPluginException in the test
///    sandbox (no real platform channel), which surfaces later as an
///    unrelated-looking test failure.
///  - EfbAdBanner only ever calls into the google_mobile_ads platform
///    channel on Android/iOS (see EfbAdBanner._loadAd's early return for
///    web/windows/macOS/linux); `flutter test` resolves defaultTargetPlatform
///    from the host OS, so on the desktop platforms this repo actually ships
///    for, ads never touch a platform channel here -- nothing to mock.
///
/// Never use `tester.pumpAndSettle()` on these screens: several providers
/// (METAR fetch, GitHub release check, airport DB network refresh) make
/// real, unmocked HTTP calls that can hang well past pumpAndSettle's
/// timeout. Use `pump()` with a bounded duration instead.
void _mockPrefs() => SharedPreferences.setMockInitialValues({});

/// For tab content that in production is placed directly in a bounded
/// space (no scroll ancestor) -- currently just ChecklistsTab, which
/// relies on that bounded height for its internal `Expanded` list.
Future<void> pumpBoundedScreen(WidgetTester tester, Widget child) async {
  _mockPrefs();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Scaffold(body: child),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// For tab content that in production is placed inside a
/// SingleChildScrollView (FlightPlannerTab, FlightMonitorTab).
Future<void> pumpScrollableScreen(WidgetTester tester, Widget child) async {
  _mockPrefs();
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: ThemeData(extensions: const [AppColors.light]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 50));
}

/// For a full top-level screen that builds its own Scaffold/MaterialApp
/// contract (HomeScreen).
Future<void> pumpFullScreen(WidgetTester tester, Widget child) async {
  _mockPrefs();
  await tester.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
  await tester.pump(const Duration(milliseconds: 50));
}
