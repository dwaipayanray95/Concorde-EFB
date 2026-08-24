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
import '../widgets/entrance_fader.dart';
import '../widgets/smooth_scroll_wrapper.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';
import '../core/app_version.dart';
import '../core/sim_bridge_launcher.dart';
import '../core/app_links.dart';
import 'widgets/app_header.dart';
import 'tabs/flight_planner_tab.dart';
import 'tabs/checklists_tab.dart';
import 'tabs/flight_monitor_tab.dart';

/// App shell: background, static header, tab selector, and the version
/// badge. Each tab's actual content lives in screens/tabs/*.
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
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We hope you enjoyed using the EFB! Would you like to leave a 5-star rating on flightsim.to before you go?',
                  textAlign: TextAlign.center,
                  style: uiText(context, color: colors.textSecondary, size: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  SimBridgeLauncher.stop();
                  SimBridgeLauncher.stopWatching();
                  await windowManager.destroy();
                },
                child: Text(
                  'NO THANKS',
                  style: uiText(context, color: colors.textDim),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse(AppLinks.flightsimTo);
                  try {
                    await launchUrl(url);
                  } catch (_) {}
                  if (context.mounted) Navigator.of(context).pop();
                  SimBridgeLauncher.stop();
                  SimBridgeLauncher.stopWatching();
                  await windowManager.destroy();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'RATE 5 STARS',
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
          body: SafeArea(
            child: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    return Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width > 1080
                              ? MediaQuery.of(context).size.width
                              : 1080,
                          height: height,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(
                                  left: 40,
                                  right: 40,
                                  top: 48,
                                ),
                                child: EntranceFader(
                                  key: const ValueKey('global-header'),
                                  delay: Duration.zero,
                                  child: AppHeader(
                                    hasUpdate: _hasUpdate,
                                    latestVersion: _latestVersion,
                                    trailing: _buildTabSelector(context),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              Expanded(
                                child: selectedTab == 0
                                    ? SmoothScrollWrapper(
                                        controller: _tab0Controller,
                                        child: SingleChildScrollView(
                                          controller: _tab0Controller,
                                          key: const ValueKey('scroll-tab-0'),
                                          scrollDirection: Axis.vertical,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.only(
                                            left: 40,
                                            right: 40,
                                            bottom: 48,
                                          ),
                                          child: const FlightPlannerTab(),
                                        ),
                                      )
                                    : selectedTab == 1
                                    ? Padding(
                                        key: const ValueKey('padding-tab-1'),
                                        padding: const EdgeInsets.only(
                                          left: 40,
                                          right: 40,
                                          bottom: 48,
                                        ),
                                        child: const ChecklistsTab(),
                                      )
                                    : SmoothScrollWrapper(
                                        controller: _tab2Controller,
                                        child: SingleChildScrollView(
                                          controller: _tab2Controller,
                                          key: const ValueKey('scroll-tab-2'),
                                          scrollDirection: Axis.vertical,
                                          physics:
                                              const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.only(
                                            left: 40,
                                            right: 40,
                                            bottom: 48,
                                          ),
                                          child: const FlightMonitorTab(),
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  bottom: 16,
                  right: 0,
                  child: InkWell(
                    onTap: () async {
                      final url = Uri.parse(AppLinks.changelog);
                      try {
                        await launchUrl(url);
                      } catch (_) {}
                    },
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    mouseCursor: SystemMouseCursors.click,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border.all(
                          color: colors.dividerStrong,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppVersion.display,
                            style: uiText(
                              context,
                              size: 11,
                              weight: FontWeight.bold,
                              color: colors.textDim,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.open_in_new,
                            size: 10,
                            color: colors.textDim,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTabSelector(BuildContext context) {
    return Row(
      children: [
        _buildTabButton(context, 0, 'PLANNER', Icons.flight_takeoff),
        const SizedBox(width: 16),
        _buildTabButton(context, 1, 'CHECKLISTS', Icons.playlist_add_check),
        const SizedBox(width: 16),
        _buildTabButton(context, 2, 'MONITOR', Icons.monitor_heart),
      ],
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    int index,
    String label,
    IconData icon,
  ) {
    final colors = context.colors;
    final isSelected = selectedTab == index;
    return InkWell(
      onTap: () => setState(() => selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      mouseCursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? colors.accent : colors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colors.accent : colors.dividerStrong,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : colors.textDim,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: uiText(
                context,
                size: 13,
                weight: FontWeight.bold,
                color: isSelected ? Colors.white : colors.textDim,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
