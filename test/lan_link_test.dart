import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:concorde_efb/core/app_colors.dart';
import 'package:concorde_efb/features/flight_monitor/data/services/lan_link.dart';
import 'package:concorde_efb/features/flight_monitor/presentation/widgets/flight_monitor/wifi_link_card.dart';

void main() {
  test('beacon parsing', () {
    expect(
      parseBeaconName(
        utf8.encode(
          jsonEncode({
            'app': 'concorde-efb-bridge',
            'v': 1,
            'port': 8082,
            'host': 'SIM-PC',
          }),
        ),
      ),
      'SIM-PC',
    );
    expect(parseBeaconName(utf8.encode('{"app":"other"}')), isNull);
    expect(parseBeaconName(utf8.encode('garbage')), isNull);
  });

  test('remote bridge url carries the pairing code', () {
    const r = RemoteBridge(host: '192.168.1.20', code: '482913');
    expect(r.isConfigured, isTrue);
    expect(r.url, 'ws://192.168.1.20:8082/?code=482913');
    expect(
      const RemoteBridge(host: '192.168.1.20', code: '12').isConfigured,
      isFalse,
    );
  });

  group('platform remote client classification', () {
    test('macOS, Android and iOS are remote clients; Windows is host', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(isRemoteClientPlatform, isTrue);
      expect(isWindowsDesktop, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isRemoteClientPlatform, isTrue);
      expect(isWindowsDesktop, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(isRemoteClientPlatform, isTrue);
      expect(isWindowsDesktop, isFalse);

      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(isRemoteClientPlatform, isFalse);
      expect(isWindowsDesktop, isTrue);

      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('WifiLinkCard', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('renders connect UI on macOS', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(extensions: const [AppColors.dark]),
              home: const Scaffold(body: WifiLinkCard()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('CONNECT TO YOUR SIM PC'), findsOneWidget);
        expect(find.text('PC ADDRESS'), findsOneWidget);
        expect(find.text('PAIRING CODE'), findsOneWidget);
        expect(find.text('CONNECT'), findsOneWidget);

        final helpIcon = find.byIcon(Icons.help_outline_rounded);
        expect(helpIcon, findsOneWidget);
        final tooltip = tester.widget<Tooltip>(
          find.ancestor(of: helpIcon, matching: find.byType(Tooltip)),
        );
        expect(tooltip.message, contains('STEPS TO CONNECT'));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('renders sharing UI on Windows', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData(extensions: const [AppColors.dark]),
              home: const Scaffold(body: WifiLinkCard()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('SHARE TO PHONE / TABLET / MAC'), findsOneWidget);
        expect(find.byType(Switch), findsOneWidget);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });
  });
}
