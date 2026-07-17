import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/efb_providers.dart';
import '../widgets/entrance_fader.dart';
import '../widgets/smooth_scroll_wrapper.dart';
import '../widgets/ambient_glow.dart';
import '../core/ui_tokens.dart';
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
      final response = await http.get(
        Uri.parse(AppLinks.githubReleasesLatestApi),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));

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
    final isDesktop = !kIsWeb && (
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux
    );

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
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF0F172A),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
            ),
            title: Text(
              'RATE CONCORDE EFB',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'We hope you enjoyed using the EFB! Would you like to leave a 5-star rating on flightsim.to before you go?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: UiTokens.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  SimBridgeLauncher.stop();
                  await windowManager.destroy();
                },
                child: Text(
                  'NO THANKS',
                  style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim),
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
                  await windowManager.destroy();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: UiTokens.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: Text(
                  'RATE 5 STARS',
                  style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      await prefs.setBool('is_first_launch', false);
      SimBridgeLauncher.stop();
      await windowManager.destroy();
    }
  }

  @override
  Widget build(BuildContext context) {
    final airportDbAsync = ref.watch(airportDbProvider);

    return airportDbAsync.when(
      loading: () => Scaffold(
        backgroundColor: UiTokens.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: UiTokens.accent),
              const SizedBox(height: 24),
              Text(
                'LOADING AIRPORT DATABASE...',
                style: GoogleFonts.plusJakartaSans(
                  color: UiTokens.textSecondary,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: UiTokens.bg,
        body: Center(
          child: Text(
            'Error loading database: $err',
            style: GoogleFonts.plusJakartaSans(color: UiTokens.error),
          ),
        ),
      ),
      data: (db) {
        return Scaffold(
          backgroundColor: UiTokens.bg,
          body: SafeArea(
            child: Stack(
              children: [
                // Static ambient background. Radial gradients give the same
                // soft-glow look as blurred circles without paying for a
                // full-screen BackdropFilter every frame.
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(color: UiTokens.bg),
                    child: const Stack(
                      children: [
                        AmbientGlow(top: -300, left: -300, size: 800, color: Color(0xFF1E3A8A), alpha: 0.15),
                        AmbientGlow(bottom: -100, right: -250, size: 900, color: Color(0xFF4C1D95), alpha: 0.12),
                        AmbientGlow(top: 0, right: 0, size: 700, color: Color(0xFF0369A1), alpha: 0.12),
                      ],
                    ),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final height = constraints.maxHeight;
                    return Scrollbar(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width > 1080 ? MediaQuery.of(context).size.width : 1080,
                          height: height,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Global static header and tab selector (Animates only once on app startup)
                              Padding(
                                padding: const EdgeInsets.only(left: 40, right: 40, top: 48),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    EntranceFader(
                                      key: const ValueKey('global-header'),
                                      delay: Duration.zero,
                                      child: AppHeader(hasUpdate: _hasUpdate, latestVersion: _latestVersion),
                                    ),
                                    const SizedBox(height: 32),
                                    EntranceFader(
                                      key: const ValueKey('global-tabs'),
                                      delay: const Duration(milliseconds: 100),
                                      child: _buildTabSelector(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Dynamic tab views (cascade anims play on tab switches)
                              Expanded(
                                child: selectedTab == 0
                                    ? SmoothScrollWrapper(
                                        controller: _tab0Controller,
                                        child: SingleChildScrollView(
                                          controller: _tab0Controller,
                                          key: const ValueKey('scroll-tab-0'),
                                          scrollDirection: Axis.vertical,
                                          physics: const BouncingScrollPhysics(),
                                          padding: const EdgeInsets.only(left: 40, right: 40, bottom: 48),
                                          child: const FlightPlannerTab(),
                                        ),
                                      )
                                    : selectedTab == 1
                                        ? Padding(
                                            key: const ValueKey('padding-tab-1'),
                                            padding: const EdgeInsets.only(left: 40, right: 40, bottom: 48),
                                            child: const ChecklistsTab(),
                                          )
                                        : SmoothScrollWrapper(
                                            controller: _tab2Controller,
                                            child: SingleChildScrollView(
                                              controller: _tab2Controller,
                                              key: const ValueKey('scroll-tab-2'),
                                              scrollDirection: Axis.vertical,
                                              physics: const BouncingScrollPhysics(),
                                              padding: const EdgeInsets.only(left: 40, right: 40, bottom: 48),
                                              child: const FlightMonitorTab(),
                                            ),
                                          ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
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
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          bottomLeft: Radius.circular(8),
                        ),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            AppVersion.display,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: UiTokens.textDim,
                              fontFeatures: const [FontFeature.enable('smcp')],
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.open_in_new,
                            size: 10,
                            color: UiTokens.textDim,
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

  Widget _buildTabSelector() {
    return Row(
      children: [
        _buildTabButton(0, 'FLIGHT PLANNER', Icons.flight_takeoff),
        const SizedBox(width: 16),
        _buildTabButton(1, 'CHECKLISTS', Icons.playlist_add_check),
        const SizedBox(width: 16),
        _buildTabButton(2, 'FLIGHT MONITOR', Icons.monitor_heart),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final isSelected = selectedTab == index;
    return InkWell(
      onTap: () => setState(() => selectedTab = index),
      borderRadius: BorderRadius.circular(12),
      mouseCursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? UiTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? UiTokens.accent : Colors.white.withValues(alpha: 0.05),
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: UiTokens.accent.withValues(alpha: 0.25),
                    blurRadius: 12,
                    spreadRadius: -2,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isSelected ? Colors.white : UiTokens.textDim, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : UiTokens.textDim,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
