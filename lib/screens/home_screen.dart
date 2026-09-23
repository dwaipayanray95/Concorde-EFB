import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/efb_providers.dart';
import '../widgets/smooth_scroll_wrapper.dart';
import '../widgets/efb_nav_rail.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';
import '../core/app_version.dart';
import '../core/sim_bridge_launcher.dart';
import '../core/app_links.dart';
import 'widgets/cockpit_status_bar.dart';
import 'tabs/flight_planner_tab.dart';
import 'tabs/checklists_tab.dart';
import 'tabs/flight_monitor_tab.dart';

/// App shell: Left EFB Navigation Rail + Top Cockpit Status Bar + Responsive Viewport.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  int selectedTab = 0;

  String? _latestVersion;
  bool _hasUpdate = false;

  final ScrollController _tab0Controller = ScrollController();
  final ScrollController _tab2Controller = ScrollController();

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkForUpdates();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _tab0Controller.dispose();
    _tab2Controller.dispose();
    super.dispose();
  }

  bool _isNewerVersion(String remote, String local) {
    try {
      final remoteParts = remote.split('.').map(int.parse).toList();
      final localParts = local.split('.').map(int.parse).toList();

      final maxLength = math.max(remoteParts.length, localParts.length);
      for (int i = 0; i < maxLength; i++) {
        final remoteVal = i < remoteParts.length ? remoteParts[i] : 0;
        final localVal = i < localParts.length ? localParts[i] : 0;

        if (remoteVal > localVal) return true;
        if (remoteVal < localVal) return false;
      }
    } catch (_) {}
    return false;
  }

  void _checkForUpdates() async {
    try {
      final response = await http
          .get(
            Uri.parse(AppLinks.githubReleasesLatestApi),
            headers: {'Accept': 'application/vnd.github.v3+json'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String?;
        if (tagName != null) {
          final remoteVersion = tagName.replaceAll(RegExp(r'^[vV]'), '');
          if (mounted && _isNewerVersion(remoteVersion, AppVersion.full)) {
            setState(() {
              _latestVersion = remoteVersion;
              _hasUpdate = true;
            });
          }
        }
      }
    } catch (_) {}
  }

  @override
  void onWindowClose() async {
    final isDesktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.linux);

    if (!isDesktop) {
      Navigator.of(context).pop();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('is_first_launch') ?? true;
    final hasRatedPrompted = prefs.getBool('has_rated_prompted') ?? false;

    if (isFirstLaunch && !hasRatedPrompted) {
      await prefs.setBool('has_rated_prompted', true);
      await prefs.setBool('is_first_launch', false);

      if (mounted) {
        final colors = context.colors;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: colors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colors.dividerStrong, width: 1.5),
            ),
            title: Text(
              'RATE CONCORDE EFB',
              textAlign: TextAlign.center,
              style: uiText(
                context,
                color: colors.textPrimary,
                weight: FontWeight.w900,
                size: 16,
                letterSpacing: 1.5,
              ),
            ),
            content: Text(
              'If you enjoy using Concorde EFB for MSFS, please consider giving it a rating on flightsim.to!',
              textAlign: TextAlign.center,
              style: uiText(
                context,
                color: colors.textSecondary,
                size: 13,
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  SimBridgeLauncher.stop();
                  SimBridgeLauncher.stopWatching();
                  await windowManager.destroy();
                },
                child: Text(
                  'LATER',
                  style: uiText(
                    context,
                    color: colors.textDim,
                    weight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  SimBridgeLauncher.stop();
                  SimBridgeLauncher.stopWatching();
                  final url = Uri.parse(AppLinks.flightsimTo);
                  try {
                    await launchUrl(url);
                  } catch (_) {}
                  await windowManager.destroy();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                child: Text(
                  'RATE ON FLIGHTSIM.TO',
                  style: uiText(
                    context,
                    color: Colors.white,
                    weight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      await prefs.setBool('is_first_launch', false);
      SimBridgeLauncher.stop();
      SimBridgeLauncher.stopWatching();
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final airportDbAsync = ref.watch(airportDbProvider);

    return airportDbAsync.when(
      loading: () => Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: colors.accent),
              const SizedBox(height: 24),
              Text(
                'LOADING AIRPORT DATABASE...',
                style: uiText(
                  context,
                  color: colors.textSecondary,
                  letterSpacing: 3,
                  weight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: colors.bg,
        body: Center(
          child: Text(
            'Error loading database: $err',
            style: uiText(context, color: colors.error),
          ),
        ),
      ),
      data: (db) {
        return Scaffold(
          backgroundColor: colors.bg,
          body: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 720;

              final mainContent = SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Cockpit Top Status Bar
                    Padding(
                      padding: isCompact
                          ? const EdgeInsets.fromLTRB(12, 10, 12, 8)
                          : const EdgeInsets.fromLTRB(20, 14, 20, 12),
                      child: CockpitStatusBar(
                        hasUpdate: _hasUpdate,
                        latestVersion: _latestVersion,
                      ),
                    ),

                    // Tab View Content
                    Expanded(
                      child: selectedTab == 0
                          ? SmoothScrollWrapper(
                              controller: _tab0Controller,
                              child: SingleChildScrollView(
                                controller: _tab0Controller,
                                key: const ValueKey('scroll-tab-0'),
                                scrollDirection: Axis.vertical,
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  isCompact ? 12 : 20,
                                  4,
                                  isCompact ? 12 : 20,
                                  24,
                                ),
                                child: const FlightPlannerTab(),
                              ),
                            )
                          : selectedTab == 1
                          ? Padding(
                              key: const ValueKey('padding-tab-1'),
                              padding: EdgeInsets.fromLTRB(
                                isCompact ? 12 : 20,
                                4,
                                isCompact ? 12 : 20,
                                24,
                              ),
                              child: const ChecklistsTab(),
                            )
                          : SmoothScrollWrapper(
                              controller: _tab2Controller,
                              child: SingleChildScrollView(
                                controller: _tab2Controller,
                                key: const ValueKey('scroll-tab-2'),
                                scrollDirection: Axis.vertical,
                                physics: const BouncingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  isCompact ? 12 : 20,
                                  4,
                                  isCompact ? 12 : 20,
                                  24,
                                ),
                                child: const FlightMonitorTab(),
                              ),
                            ),
                    ),
                  ],
                ),
              );

              if (isCompact) {
                return Column(
                  children: [
                    Expanded(child: mainContent),
                    // Compact Bottom Navigation for mobile screens
                    Container(
                      decoration: BoxDecoration(
                        color: colors.surface,
                        border: Border(
                          top: BorderSide(
                            color: colors.dividerStrong.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                        ),
                      ),
                      child: SafeArea(
                        top: false,
                        child: NavigationBar(
                          selectedIndex: selectedTab,
                          height: 56,
                          backgroundColor: Colors.transparent,
                          indicatorColor: colors.accent,
                          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                          onDestinationSelected: (idx) {
                            setState(() => selectedTab = idx);
                          },
                          destinations: [
                            NavigationDestination(
                              icon: Icon(Icons.flight_takeoff, color: colors.textSecondary, size: 20),
                              selectedIcon: const Icon(Icons.flight_takeoff, color: Color(0xFF101012), size: 20),
                              label: 'PLAN',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.playlist_add_check, color: colors.textSecondary, size: 20),
                              selectedIcon: const Icon(Icons.playlist_add_check, color: Color(0xFF101012), size: 20),
                              label: 'CHECK',
                            ),
                            NavigationDestination(
                              icon: Icon(Icons.monitor_heart, color: colors.textSecondary, size: 20),
                              selectedIcon: const Icon(Icons.monitor_heart, color: Color(0xFF101012), size: 20),
                              label: 'MONITOR',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Authentic left navigation rail for tablet/desktop
                  EfbNavRail(
                    selectedIndex: selectedTab,
                    onDestinationSelected: (idx) {
                      setState(() => selectedTab = idx);
                    },
                  ),

                  // 2. Main EFB tablet content area
                  Expanded(child: mainContent),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
