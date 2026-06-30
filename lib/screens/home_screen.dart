import 'dart:math' as math;
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/efb_providers.dart';
import '../providers/badge_provider.dart';
import '../widgets/efb_card.dart';
import '../widgets/efb_text_field.dart';
import '../widgets/efb_launches_badge.dart';
import '../widgets/wind_arrow.dart';
import '../widgets/efb_glass_container.dart';
import '../widgets/efb_ad_banner.dart';
import '../core/ui_tokens.dart';
import '../core/concorde_constants.dart';
import '../core/metar_parser.dart';
import '../models/concorde_models.dart';
import '../services/simbrief_service.dart';
import '../models/airport.dart';
import '../core/app_version.dart';

final numFormat = NumberFormat('#,###');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> with WindowListener {
  bool showDepRaw = false;
  bool showArrRaw = false;
  int selectedTab = 0;
  String selectedChecklistPhase = 'cold_dark';

  String? _latestVersion;
  bool _hasUpdate = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkForUpdates();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
        Uri.parse('https://api.github.com/repos/dwaipayanray95/Concorde-EFB/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final tagName = data['tag_name'] as String?;
        if (tagName != null) {
          final remoteVersion = tagName.replaceAll(RegExp(r'^[vV]'), '');
          if (_isNewerVersion(remoteVersion, AppVersion.full)) {
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
                  await windowManager.destroy();
                },
                child: Text(
                  'NO THANKS',
                  style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final url = Uri.parse('https://flightsim.to/addon/101890/concorde-efb');
                  try {
                    await launchUrl(url);
                  } catch (_) {}
                  if (context.mounted) Navigator.of(context).pop();
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
                // Dynamic Background for Refraction
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(color: UiTokens.bg),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -100,
                          left: -100,
                          child: Container(
                            width: 400,
                            height: 400,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF1E3A8A).withValues(alpha: 0.15),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 100,
                          right: -50,
                          child: Container(
                            width: 500,
                            height: 500,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF4C1D95).withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 200,
                          right: 200,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF0369A1).withValues(alpha: 0.12),
                            ),
                          ),
                        ),
                        BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                          child: Container(color: Colors.transparent),
                        ),
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
                        child: SizedBox(
                          width: MediaQuery.of(context).size.width > 1080 ? MediaQuery.of(context).size.width : 1080,
                          height: height,
                          child: selectedTab == 0
                              ? SingleChildScrollView(
                                  scrollDirection: Axis.vertical,
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHeader(ref),
                                      const SizedBox(height: 32),
                                      _buildTabSelector(),
                                      const SizedBox(height: 32),
                                      _buildFlightPlanAndCruiseRow(ref),
                                      const SizedBox(height: 32),
                                      _buildPerformanceCalculatorSection(ref),
                                      const SizedBox(height: 64),
                                      _buildFooter(),
                                    ],
                                  ),
                                )
                              : Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildHeader(ref),
                                      const SizedBox(height: 32),
                                      _buildTabSelector(),
                                      const SizedBox(height: 32),
                                      Expanded(
                                        child: _buildChecklistsSection(ref),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ),
                    );
                  }
                ),
                Positioned(
                  bottom: 16,
                  right: 0,
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
                    child: Text(
                      AppVersion.display,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: UiTokens.textDim,
                        fontFeatures: const [FontFeature.enable('smcp')],
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

  Widget _buildHeader(WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_hasUpdate && _latestVersion != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: UiTokens.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UiTokens.accent.withValues(alpha: 0.4), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: UiTokens.accent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A NEW UPDATE IS AVAILABLE',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: UiTokens.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version v$_latestVersion is now ready. Download it from flightsim.to to get the latest features.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse('https://flightsim.to/addon/101890/concorde-efb');
                    try {
                      await launchUrl(url);
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTokens.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'DOWNLOAD NOW',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: UiTokens.accent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/app-icon.png', width: 64, height: 64, errorBuilder: (context, error, stackTrace) => const Icon(Icons.airplanemode_active, color: UiTokens.accent, size: 64)),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Concorde EFB',
                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flight planning & performance for MSFS.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: UiTokens.textSecondary),
                  ),
                ],
              ),
            ),
            _buildHeaderStat('NAV DB', 'Loaded', valueColor: UiTokens.success),
            const SizedBox(width: 32),
            _buildHeaderStat('TAS', '1164 kt'),
            const SizedBox(width: 32),
            _buildHeaderStat('MTOW', '${numFormat.format(ConcordeConstants.weights.mtowKg)} kg'),
            const SizedBox(width: 32),
            _buildHeaderStat('MLW', '${numFormat.format(ConcordeConstants.weights.mlwKg)} kg'),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderStat(String label, String value, {Color valueColor = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w800, color: UiTokens.textSecondary, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor),
        ),
      ],
    );
  }

  Widget _buildFlightPlanAndCruiseRow(WidgetRef ref) {
    return Column(
      children: [
        _buildFlightPlanSection(ref),
        const SizedBox(height: 32),
        _buildCruiseAndFuelSection(ref),
      ],
    );
  }

  Widget _buildFlightPlanSection(WidgetRef ref) {
    final isLoading = ref.watch(simbriefLoadingProvider);
    
    return EfbCard(
      title: 'FLIGHT PLAN',
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: EfbTextField(
                  label: 'SIMBRIEF USERNAME / ID (OPTIONAL)',
                  initialValue: ref.watch(simbriefUserProvider),
                  onChanged: (v) => ref.read(simbriefUserProvider.notifier).set(v),
                  placeholder: 'SimBrief username',
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: UiTokens.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : () async {
                    final user = ref.read(simbriefUserProvider);
                    if (user.isEmpty) return;
                    ref.read(simbriefLoadingProvider.notifier).set(true);
                    try {
                      final ofp = await SimBriefService().fetchLatestOFP(user);
                      if (ofp != null) {
                        ref.read(callSignProvider.notifier).set(ofp['general']?['atc_callsign'] ?? ofp['atc']?['callsign'] ?? '--');
                        ref.read(registrationProvider.notifier).set(ofp['aircraft']?['reg'] ?? '--');
                        ref.read(departureIcaoProvider.notifier).set(ofp['origin']?['icao_code'] ?? '');
                        ref.read(arrivalIcaoProvider.notifier).set(ofp['destination']?['icao_code'] ?? '');
                        ref.read(alternateIcaoProvider.notifier).set(ofp['alternate']?['icao_code'] ?? '');
                        ref.read(plannedDistanceProvider.notifier).set(double.tryParse(ofp['general']?['route_distance'] ?? '0') ?? 0.0);
                        ref.read(paxCountProvider.notifier).set(int.tryParse(ofp['weights']?['pax_count'] ?? '100') ?? 100);
                        
                        ref.read(departureRunwayIdProvider.notifier).set(ofp['origin']?['plan_rwy'] ?? '');
                        ref.read(arrivalRunwayIdProvider.notifier).set(ofp['destination']?['plan_rwy'] ?? '');
                        
                        ref.read(simbriefRouteProvider.notifier).set(ofp['general']?['route'] ?? '--');
                        ref.read(simbriefLoadedProvider.notifier).set(true);
                      }
                    } finally {
                      ref.read(simbriefLoadingProvider.notifier).set(false);
                    }
                  },
                  icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download, size: 16),
                  label: Text(
                    'Import',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTokens.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _buildInfoChip(
                  'CALL SIGN',
                  ref.watch(callSignProvider),
                  glassColor: ref.watch(simbriefLoadedProvider)
                      ? const Color(0x3310B981) // Solid glass green (Emerald)
                      : null,
                  boxShadow: ref.watch(simbriefLoadedProvider)
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildInfoChip(
                  'REGISTRATION',
                  ref.watch(registrationProvider),
                  glassColor: ref.watch(simbriefLoadedProvider)
                      ? const Color(0x33F59E0B) // Solid glass yellow (Amber)
                      : null,
                  boxShadow: ref.watch(simbriefLoadedProvider)
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoChip('PASSENGERS', '${ref.watch(paxCountProvider)}', isNumeric: true)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: EfbGlassContainer(
                  blur: 10,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ref.watch(departureIcaoProvider)} → ${ref.watch(arrivalIcaoProvider)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: UiTokens.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'ALT: ${ref.watch(alternateIcaoProvider)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: UiTokens.textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    final route = ref.read(simbriefRouteProvider);
                    if (route.isNotEmpty && route != '--') {
                      Clipboard.setData(ClipboardData(text: route));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Route copied to clipboard!',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: UiTokens.surface,
                        ),
                      );
                      
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: UiTokens.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(
                            'FULL ROUTE',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: SelectableText(
                              route,
                              style: GoogleFonts.jetBrainsMono(
                                color: UiTokens.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'CLOSE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: UiTokens.textDim,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(12),
                  child: EfbGlassContainer(
                    blur: 10,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.route, color: UiTokens.textDim, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ref.watch(simbriefRouteProvider),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                color: ref.watch(simbriefRouteProvider) == '--'
                                    ? UiTokens.textDim
                                    : UiTokens.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy_all,
                            color: ref.watch(simbriefRouteProvider) == '--'
                                ? UiTokens.textDim.withValues(alpha: 0.5)
                                : UiTokens.accent,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildInfoChip('ROUTE DISTANCE', '${ref.watch(plannedDistanceProvider).round()} NM', alignLeft: true, isNumeric: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, {bool alignLeft = false, bool isNumeric = false, Color? glassColor, List<BoxShadow>? boxShadow}) {
    return EfbGlassContainer(
      blur: 10,
      borderRadius: BorderRadius.circular(12),
      color: glassColor,
      boxShadow: boxShadow,
      child: Container(
        height: 48,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: glassColor != null ? Colors.white.withValues(alpha: 0.6) : UiTokens.textDim,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: (isNumeric ? GoogleFonts.jetBrainsMono : GoogleFonts.plusJakartaSans)(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: glassColor != null ? Colors.white : UiTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCruiseAndFuelSection(WidgetRef ref) {
    final fuel = ref.watch(fuelBreakdownProvider);
    final mission = ref.watch(missionProfileProvider);
    final weights = ref.watch(weightsProvider);
    final trim = ref.watch(trimTankFuelProvider);
    final extra = ref.watch(extraFuelProvider);
    final totalFuel = fuel.blockKg + trim + extra;
    final isOverCapacity = totalFuel > ConcordeConstants.weights.fuelCapacityKg;
    final direction = ref.watch(flightDirectionProvider);

    // Calculate dynamic flight burn rate (kg/hour) and fuel endurance
    final double averageBurnRate = mission.totalTimeH > 0 && mission.tripKg > 0
        ? (mission.tripKg / mission.totalTimeH)
        : (ConcordeConstants.fuel.burnKgPerNm * ConcordeConstants.speeds.cruiseTasKt);

    final double airborneFuel = math.max(0.0, totalFuel - fuel.taxiKg);
    final double fuelEnduranceH = averageBurnRate > 0 ? (airborneFuel / averageBurnRate) : 0.0;
    
    final double reserveFuel = fuel.finalReserveKg + fuel.alternateKg + fuel.contingencyKg;
    final double reserveTimeH = averageBurnRate > 0 ? (reserveFuel / averageBurnRate) : 0.0;
    final double etePlusReservesH = mission.totalTimeH + reserveTimeH;

    return EfbCard(
      title: 'CRUISE & FUEL MANAGEMENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _buildTimeBox('TOTAL FLIGHT TIME', mission.totalTimeH)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeBox('CLIMB', mission.climb.timeH)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeBox('CRUISE', mission.cruise.timeH)),
              const SizedBox(width: 16),
              Expanded(child: _buildTimeBox('DESCENT', mission.descent.timeH)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Cruise-climb profile: FL${mission.initialCruiseFl} to FL${mission.targetCruiseFl}, with acceleration phase included in cruise time/fuel.',
            style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 10),
          ),
          const SizedBox(height: 32),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: EfbTextField(
                            label: 'PLANNED DISTANCE (NM)',
                            initialValue: ref.watch(plannedDistanceProvider).round().toString(),
                            onChanged: (v) => ref.read(plannedDistanceProvider.notifier).set(double.tryParse(v) ?? 0.0),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              EfbTextField(
                                label: 'CRUISE FLIGHT LEVEL (FL)',
                                initialValue: ref.watch(cruiseFLProvider).round().toString(),
                                onChanged: (v) => ref.read(cruiseFLProvider.notifier).set(double.tryParse(v) ?? 590.0, direction),
                                keyboardType: TextInputType.number,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Direction (auto): ${direction == "E" ? "Eastbound" : direction == "W" ? "Westbound" : "unknown"}. snap to Non-RVSM.',
                                style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EfbTextField(
                            label: 'ALTERNATE ICAO (ALT)',
                            initialValue: ref.watch(alternateIcaoProvider),
                            onChanged: (v) => ref.read(alternateIcaoProvider.notifier).set(v),
                            textCapitalization: TextCapitalization.characters,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'ADVANCED',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w900, color: UiTokens.textPrimary, letterSpacing: 2),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: EfbTextField(label: 'TAXI FUEL (KG)', initialValue: ref.watch(taxiFuelProvider).round().toString(), onChanged: (v) => ref.read(taxiFuelProvider.notifier).set(double.tryParse(v) ?? 0.0), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: EfbTextField(label: 'CONTINGENCY (%)', initialValue: ref.watch(contingencyPctProvider).round().toString(), onChanged: (v) => ref.read(contingencyPctProvider.notifier).set(double.tryParse(v) ?? 0.0), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: EfbTextField(label: 'FINAL RESERVE (KG)', initialValue: ref.watch(finalReserveFuelProvider).round().toString(), onChanged: (v) => ref.read(finalReserveFuelProvider.notifier).set(double.tryParse(v) ?? 0.0), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        Expanded(child: EfbTextField(label: 'TRIM TANK FUEL (KG)', initialValue: ref.watch(trimTankFuelProvider).round().toString(), onChanged: (v) => ref.read(trimTankFuelProvider.notifier).set(double.tryParse(v) ?? 0.0), keyboardType: TextInputType.number)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(child: EfbTextField(label: 'EXTRA FUEL (KG)', initialValue: ref.watch(extraFuelProvider).round().toString(), onChanged: (v) => ref.read(extraFuelProvider.notifier).set(double.tryParse(v) ?? 0.0), keyboardType: TextInputType.number)),
                        const SizedBox(width: 16),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: _buildBottomStatBox('COMPUTED TOW', '${numFormat.format(weights['TOW']!.round())} kg', isLarge: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBottomStatBox('FUEL ENDURANCE', _formatHoursMinutes(fuelEnduranceH))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBottomStatBox('ETE + RESERVES', _formatHoursMinutes(etePlusReservesH))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBottomStatBox('PASSENGERS', '${ref.watch(paxCountProvider)} pax', subtext: '${numFormat.format(weights['PAX']!.round())} kg @ 84 kg each')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                flex: 7,
                child: EfbGlassContainer(
                  blur: 15,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFuelRow('Trip Fuel', fuel.tripKg),
                        _buildDivider(),
                        _buildFuelRow('Taxi Fuel', fuel.taxiKg),
                        _buildDivider(),
                        _buildFuelRow('Contingency', fuel.contingencyKg),
                        _buildDivider(),
                        _buildFuelRow('Trim Fuel', trim),
                        _buildDivider(),
                        _buildFuelRow('Extra Fuel', extra),
                        _buildDivider(),
                        _buildFuelRow('Alt Fuel (${ref.watch(alternateDistanceProvider).round()} NM)', fuel.alternateKg),
                        _buildDivider(),
                        _buildFuelRow('Block Fuel', fuel.blockKg, isBold: true),
                        const SizedBox(height: 32),
                        const Divider(color: Colors.white10, thickness: 1),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Required',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: UiTokens.textPrimary),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Block + Trim + Extra (${numFormat.format(trim + extra)} kg)',
                                  style: GoogleFonts.plusJakartaSans(fontSize: 10, color: UiTokens.textSecondary.withValues(alpha: 0.5)),
                                ),
                              ],
                            ),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.baseline,
                              textBaseline: TextBaseline.alphabetic,
                              children: [
                                Text(
                                  numFormat.format(totalFuel),
                                  style: GoogleFonts.jetBrainsMono(fontSize: 28, fontWeight: FontWeight.w900, color: isOverCapacity ? UiTokens.error : UiTokens.success),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'kg',
                                  style: GoogleFonts.jetBrainsMono(fontSize: 14, color: UiTokens.textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reheat safety: climb reheat within ${ConcordeConstants.fuel.reheatMinutesCap} min cap.',
                style: GoogleFonts.plusJakartaSans(
                  color: mission.climb.timeH * 60 <= ConcordeConstants.fuel.reheatMinutesCap ? UiTokens.textDim : UiTokens.error,
                  fontSize: 12,
                ),
              ),
              if (fuelEnduranceH < etePlusReservesH)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Fuel endurance is less than required ETE + reserves.',
                    style: GoogleFonts.plusJakartaSans(color: UiTokens.error, fontSize: 12),
                  ),
                ),
              if (isOverCapacity)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Warning: Total fuel exceeds Concorde fuel capacity of ${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg.',
                    style: GoogleFonts.plusJakartaSans(color: UiTokens.error, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatHoursMinutes(double hoursDecimal) {
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  Widget _buildTimeBox(String label, double hoursDecimal) {
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return EfbGlassContainer(
      blur: 10,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.bold, color: UiTokens.textDim, letterSpacing: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: GoogleFonts.jetBrainsMono(color: Colors.white, fontWeight: FontWeight.w900),
                children: [
                  TextSpan(text: '$h', style: const TextStyle(fontSize: 22)),
                  TextSpan(text: ' h ', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: UiTokens.textSecondary, fontWeight: FontWeight.w600)),
                  TextSpan(text: m.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 22)),
                  TextSpan(text: ' m', style: GoogleFonts.plusJakartaSans(fontSize: 12, color: UiTokens.textSecondary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomStatBox(String label, String value, {bool isLarge = false, String? subtext}) {
    return EfbGlassContainer(
      blur: 10,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: UiTokens.textDim, letterSpacing: 1),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(fontSize: isLarge ? 18 : 16, fontWeight: FontWeight.w900, color: Colors.white),
            ),
            if (subtext != null) ...[
              const SizedBox(height: 4),
              Text(
                subtext,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: UiTokens.textDim, fontWeight: FontWeight.w500),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFuelRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.white : UiTokens.textSecondary),
          ),
          Text(
            numFormat.format(value.round()),
            style: GoogleFonts.jetBrainsMono(fontSize: isBold ? 18 : 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(color: Colors.white10, height: 16);

  Widget _buildPerformanceCalculatorSection(WidgetRef ref) {
    return EfbGlassContainer(
      blur: 20,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PERFORMANCE CALCULATOR',
              style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1),
            ),
            const SizedBox(height: 32),
            Text(
              'Airports & Runways',
              style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: EfbTextField(label: 'DEPARTURE ICAO', initialValue: ref.watch(departureIcaoProvider), onChanged: (v) => ref.read(departureIcaoProvider.notifier).set(v))),
                const SizedBox(width: 16),
                Expanded(child: _buildRunwayDropdown(ref, 'DEPARTURE RUNWAY', ref.watch(depAirportProvider), ref.watch(departureRunwayIdProvider), (v) => ref.read(departureRunwayIdProvider.notifier).set(v ?? ''))),
                const SizedBox(width: 32),
                Expanded(child: EfbTextField(label: 'ARRIVAL ICAO', initialValue: ref.watch(arrivalIcaoProvider), onChanged: (v) => ref.read(arrivalIcaoProvider.notifier).set(v))),
                const SizedBox(width: 16),
                Expanded(child: _buildRunwayDropdown(ref, 'ARRIVAL RUNWAY', ref.watch(arrAirportProvider), ref.watch(arrivalRunwayIdProvider), (v) => ref.read(arrivalRunwayIdProvider.notifier).set(v ?? ''))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ref.watch(departureMetarFutureProvider).when(
                    data: (metar) => _buildMetarDisplay('DEP METAR', metar, ref.watch(departureRunwayProvider), showDepRaw, () => setState(() => showDepRaw = !showDepRaw)),
                    loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                    error: (error, stack) => _buildMetarDisplay('DEP METAR', '', ref.watch(departureRunwayProvider), showDepRaw, () => setState(() => showDepRaw = !showDepRaw)),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: ref.watch(arrivalMetarFutureProvider).when(
                    data: (metar) => _buildMetarDisplay('ARR METAR', metar, ref.watch(arrivalRunwayProvider), showArrRaw, () => setState(() => showArrRaw = !showArrRaw)),
                    loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                    error: (error, stack) => _buildMetarDisplay('ARR METAR', '', ref.watch(arrivalRunwayProvider), showArrRaw, () => setState(() => showArrRaw = !showArrRaw)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Text(
                  'Takeoff Reheat (Afterburners):',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: ref.watch(useReheatTakeoffProvider),
                  onChanged: (val) => ref.read(useReheatTakeoffProvider.notifier).set(val),
                  activeThumbColor: UiTokens.accent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildPerfCard(ref, 'TAKEOFF PERFORMANCE', ref.watch(weightsProvider)['TOW']!, ref.watch(takeoffSpeedsProvider), ref.watch(takeoffFeasibilityProvider))),
                const SizedBox(width: 32),
                Expanded(child: _buildPerfCard(ref, 'LANDING PERFORMANCE', ref.watch(weightsProvider)['LW']!, ref.watch(landingSpeedsProvider), ref.watch(landingFeasibilityProvider))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRunwayDropdown(WidgetRef ref, String label, Airport? airport, String currentId, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 11, color: UiTokens.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        EfbGlassContainer(
          blur: 10,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 48,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentId.isEmpty ? null : currentId,
                items: airport?.runways.map((r) => DropdownMenuItem(value: r.id, child: Text('RWY ${r.id} • ${numFormat.format(r.lengthM)} m • ${r.heading}°'))).toList() ?? [],
                onChanged: onChanged,
                dropdownColor: const Color(0xFF1E293B),
                style: GoogleFonts.jetBrainsMono(color: UiTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                isExpanded: true,
                hint: Text('Select...', style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMetarDisplay(String title, String metarStr, Runway? runway, bool showRaw, VoidCallback onToggle) {
    final parsed = MetarParser.parseWind(metarStr);
    final qnh = MetarParser.parseQnh(metarStr);
    final tempC = MetarParser.parseTempC(metarStr);
    final vis = MetarParser.parseVisibilityKm(metarStr);
    final cat = MetarParser.parseFlightCategory(metarStr);
    final summary = MetarParser.parseWeatherSummary(metarStr);
    
    final rwyHeading = runway?.heading.toDouble();
    
    Color catColor = UiTokens.vfr;
    if (cat == 'MVFR') catColor = UiTokens.mvfr;
    if (cat == 'IFR') catColor = UiTokens.ifr;
    if (cat == 'LIFR') catColor = UiTokens.lifr;

    return InkWell(
      onTap: metarStr.isNotEmpty ? onToggle : null,
      borderRadius: BorderRadius.circular(16),
      child: EfbGlassContainer(
        blur: 15,
        borderRadius: BorderRadius.circular(16),
        color: catColor.withValues(alpha: 0.04), // Subtle glassy category tint
        boxShadow: [
          BoxShadow(
            color: catColor.withValues(alpha: 0.20), // Soft, vibrant neon glow
            blurRadius: 20,
            spreadRadius: 0,
          )
        ],
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            border: Border.all(color: catColor.withValues(alpha: 0.25), width: 1.0), // Thinner border
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: UiTokens.textSecondary, letterSpacing: 2),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 16, color: UiTokens.textSecondary),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          if (title.contains('DEP')) {
                            ref.invalidate(departureMetarFutureProvider);
                          } else {
                            ref.invalidate(arrivalMetarFutureProvider);
                          }
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        '$summary • ${tempC?.round() ?? '--'}°C',
                        style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.bold, color: UiTokens.textSecondary, letterSpacing: 1),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: catColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: catColor, width: 1.0),
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: catColor),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                        ),
                        child: Center(
                          child: WindArrow(
                            runwayHeading: rwyHeading,
                            windDir: parsed.windDirDeg,
                            windSpeedKt: parsed.windSpeedKt,
                            color: UiTokens.accent,
                            size: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        runway?.id ?? '--',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Colors.white.withValues(alpha: 0.95),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (metarStr.isNotEmpty) ...[
                          Text(
                            metarStr,
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildMetarChip('WIND', '${parsed.windDirDeg?.round() ?? 'VRB'}° ${parsed.windSpeedKt?.round() ?? '--'} kt'),
                            _buildMetarChip('VIS', '${vis != null ? (vis >= 10 ? '10+' : vis.toStringAsFixed(1)) : '--'} km'),
                            _buildMetarChip('QNH', '${qnh?.value.round() ?? '--'} ${qnh?.unit ?? ''}'),
                            if (runway != null) _buildMetarChip('RWY ELEV', '${runway.elevationFt?.round() ?? '--'} ft'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetarChip(String label, String value) {
    return EfbGlassContainer(
      blur: 5,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(fontSize: 9, color: UiTokens.textDim, fontWeight: FontWeight.bold, letterSpacing: 1),
            ),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerfCard(WidgetRef ref, String title, double weightKg, Map<String, double> speeds, RunwayFeasibility? f) {
    final double totalFuel = ref.watch(weightsProvider)['FUEL'] ?? 0.0;
    final bool isFuelOver = totalFuel > ConcordeConstants.weights.fuelCapacityKg;
    final double maxWeight = title.contains('TAKEOFF')
        ? ConcordeConstants.weights.mtowKg
        : ConcordeConstants.weights.mlwKg;
    final bool isWeightFeasible = weightKg <= maxWeight;
    final bool isFeasible = (f?.feasible ?? true) && isWeightFeasible && !isFuelOver;
    final String reqRunway = f != null ? numFormat.format(f.requiredLengthMEst.round()) : '--';
    final Color tintColor = isFeasible ? UiTokens.surface : UiTokens.error;

    return EfbGlassContainer(
      blur: 20,
      borderRadius: BorderRadius.circular(20),
      color: tintColor.withValues(alpha: 0.1),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: (isFeasible ? Colors.white : UiTokens.error).withValues(alpha: 0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (isFeasible ? UiTokens.vfr : UiTokens.error).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: (isFeasible ? UiTokens.vfr : UiTokens.error).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    isFeasible ? 'WITHIN LIMITS' : 'EXCEEDS LIMITS',
                    style: GoogleFonts.plusJakartaSans(fontSize: 10, fontWeight: FontWeight.w900, color: isFeasible ? UiTokens.vfr : UiTokens.error, letterSpacing: 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  numFormat.format(weightKg.round()),
                  style: GoogleFonts.jetBrainsMono(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(width: 4),
                Text(
                  'kg',
                  style: GoogleFonts.jetBrainsMono(fontSize: 14, color: UiTokens.textSecondary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: speeds.entries.map((e) => Expanded(
                child: EfbGlassContainer(
                  blur: 5,
                  borderRadius: BorderRadius.circular(12),
                  margin: const EdgeInsets.only(right: 12),
                  color: Colors.black.withValues(alpha: 0.3),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          e.key,
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: UiTokens.textSecondary, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          e.value.round().toString(),
                          style: GoogleFonts.jetBrainsMono(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
              )).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Runway required: $reqRunway m',
                  style: GoogleFonts.plusJakartaSans(fontSize: 14, color: UiTokens.textSecondary),
                ),
                if (!isWeightFeasible)
                  Text(
                    'EXCEEDS MAX WEIGHT (${numFormat.format(maxWeight)} kg)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: UiTokens.error, fontWeight: FontWeight.bold),
                  )
                else if (isFuelOver)
                  Text(
                    'EXCEEDS FUEL CAPACITY (${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg)',
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, color: UiTokens.error, fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EfbLaunchesBadge(),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Speeds scale with √(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim.',
          style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 12),
        ),
        const EfbAdBanner(),
      ],
    );
  }

  Widget _buildTabSelector() {
    return Row(
      children: [
        _buildTabButton(0, 'FLIGHT PLANNER', Icons.flight_takeoff),
        const SizedBox(width: 16),
        _buildTabButton(1, 'CHECKLISTS', Icons.playlist_add_check),
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

  Widget _buildChecklistsSection(WidgetRef ref) {
    final checklistState = ref.watch(checklistProvider);
    final notifier = ref.read(checklistProvider.notifier);
    final landingSpeeds = ref.watch(landingSpeedsProvider);
    final takeoffSpeeds = ref.watch(takeoffSpeedsProvider);
    final simbriefLoaded = ref.watch(simbriefLoadedProvider);
    final vappSpeed = landingSpeeds['VAPP'];
    final vappStr = (simbriefLoaded && vappSpeed != null) ? '${vappSpeed.round()} KT' : 'VAPP';
    final v1 = takeoffSpeeds['V1'];
    final vr = takeoffSpeeds['VR'];
    final v2 = takeoffSpeeds['V2'];
    final vSpeedsStr = (simbriefLoaded && v1 != null && vr != null && v2 != null)
        ? 'V1:${v1.round()} VR:${vr.round()} V2:${v2.round()}'
        : 'V-Speeds';

    final phases = [
      {'id': 'cold_dark', 'name': 'Cold & Dark Setup'},
      {'id': 'before_start', 'name': 'Before Start & Engine Start'},
      {'id': 'before_takeoff', 'name': 'Before Takeoff & Taxi'},
      {'id': 'after_takeoff', 'name': 'After Takeoff'},
      {'id': 'cruise_accel', 'name': 'Cruise & Supersonic Accel'},
      {'id': 'descent', 'name': 'Deceleration & Descent'},
      {'id': 'approach', 'name': 'Approach'},
    ];

    final Map<String, List<ChecklistItem>> checklistData = {
      'cold_dark': [
        ChecklistItem(id: 'cd_bat', item: 'Battery Switch', status: 'SPLIT A & B'),
        ChecklistItem(id: 'cd_gnd_pwr', item: 'Ground Power', status: 'ON', note: 'Ground power is highly important for system alignment!'),
        ChecklistItem(id: 'cd_crossfeed', item: 'Fuel Cross Feed Valves', status: 'ON (ALL 4 ENGINES)'),
        ChecklistItem(id: 'cd_bleed', item: 'Engine Bleed Valves', status: 'AUTO'),
        ChecklistItem(id: 'cd_heater', item: 'Engine Heater', status: 'AUTO'),
        ChecklistItem(id: 'cd_visor', item: 'Nose Visor', status: 'DOWN'),
        ChecklistItem(id: 'cd_lights', item: 'Lights & Seatbelts', status: 'ON'),
        ChecklistItem(id: 'cd_antistall', item: 'Anti-Stall Switches', status: 'ON'),
        ChecklistItem(id: 'cd_trim', item: 'Pitch Trim', status: 'CENTER (0.0)', note: 'Normalizes pitch response'),
        ChecklistItem(id: 'cd_fmc', item: 'FMC / Route', status: 'SET DEP/ARR, FLIGHT NO, CRUISE FL, SPEED to 250, & INITIAL ALT', note: 'Refer to manual or import via SimBrief'),
        ChecklistItem(id: 'cd_pos_init', item: 'FMC POS Init', status: 'Main Menu ➔ Set POS'),
        ChecklistItem(id: 'cd_v_speeds', item: 'FMC V-Speeds', status: 'Perf Page ➔ SET $vSpeedsStr'),
      ],
      'before_start': [
        ChecklistItem(id: 'bs_beacon', item: 'Beacon Lights', status: 'ON'),
        ChecklistItem(id: 'bs_pumps', item: 'Fuel Pumps', status: 'ON'),
        ChecklistItem(id: 'bs_eng_start', item: 'Engine Start Selectors', status: 'START', note: 'Standard Concorde Sequence: 3, 4, 2, 1 or 3, 2, 1, 4'),
        ChecklistItem(id: 'bs_throttle', item: 'Throttle Levers', status: 'IDLE'),
        ChecklistItem(id: 'bs_csd_on', item: 'CSD Generators 1-4', status: 'ON', note: 'Engage once engines are stabilized'),
        ChecklistItem(id: 'bs_gnd_pwr_off', item: 'Ground Power', status: 'OFF / DISCONNECT'),
      ],
      'before_takeoff': [
        ChecklistItem(id: 'bt_controls', item: 'Flight Controls', status: 'CHECKED'),
        ChecklistItem(id: 'bt_visor', item: 'Nose Visor', status: '5° (TAXI/TAKEOFF)'),
        ChecklistItem(id: 'bt_reheat', item: 'Reheat Selectors', status: 'ARMED'),
        ChecklistItem(id: 'bt_lights', item: 'Landing Lights', status: 'AS REQUIRED'),
        ChecklistItem(id: 'bt_speed_arm', item: 'Speed Arming', status: 'Select IAS ACQ Button'),
        ChecklistItem(id: 'bt_ap_at_off', item: 'Autopilot / Autothrottle', status: 'DISENGAGED'),
      ],
      'after_takeoff': [
        ChecklistItem(id: 'at_gear', item: 'Landing Gear', status: 'UP'),
        ChecklistItem(id: 'at_autothrottle', item: 'Autothrottle', status: 'ON'),
        ChecklistItem(id: 'at_reheat_off', item: 'Reheats (Afterburners)', status: 'OFF'),
        ChecklistItem(id: 'at_visor', item: 'Nose Visor', status: 'UP'),
      ],
      'cruise_accel': [
        ChecklistItem(id: 'ca_reheat', item: 'Reheats (Afterburners)', status: 'ENGAGE (1 & 4, then 2 & 3)', note: 'Cap at 25 min'),
        ChecklistItem(id: 'ca_cg', item: 'Fuel Transfer (CG Management)', status: 'PUMP AFT (Tanks 9 & 11)', note: 'Target 59% MAC at Mach 2.0'),
        ChecklistItem(id: 'ca_ap', item: 'Autopilot / Max Climb', status: 'ENGAGED'),
      ],
      'descent': [
        ChecklistItem(id: 'de_reheat', item: 'Reheats', status: 'OFF'),
        ChecklistItem(id: 'de_throttle', item: 'Throttles', status: 'SET SPEED & SELECT IAS ACQ (or IDLE / RETRACT)'),
        ChecklistItem(id: 'de_cg', item: 'Fuel Transfer (CG Management)', status: 'PUMP FORWARD', note: 'Target 53% MAC before landfall'),
      ],
      'approach': [
        ChecklistItem(id: 'ap_speed', item: 'Approach Speed', status: 'SET $vappStr'),
        ChecklistItem(id: 'ap_visor', item: 'Nose Visor', status: 'DOWN (17.5°)', note: 'Move to 5° or 17.5° depending on speed/glideslope'),
        ChecklistItem(id: 'ap_gear', item: 'Landing Gear', status: 'DOWN', note: 'Extend below 270 KIAS'),
      ],
    };

    final currentItems = checklistData[selectedChecklistPhase] ?? [];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Navigation Panel
        Expanded(
          flex: 3,
          child: EfbGlassContainer(
            blur: 20,
            borderRadius: BorderRadius.circular(16),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: phases.map((phase) {
                  final isSelected = selectedChecklistPhase == phase['id'];
                  final phaseItems = checklistData[phase['id']] ?? [];
                  final checkedCount = phaseItems.where((item) => checklistState[item.id] ?? false).length;
                  final totalCount = phaseItems.length;
                  final isCompleted = checkedCount == totalCount && totalCount > 0;

                  return InkWell(
                    onTap: () => setState(() => selectedChecklistPhase = phase['id']!),
                    borderRadius: BorderRadius.circular(12),
                    mouseCursor: SystemMouseCursors.click,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: isSelected ? UiTokens.accent.withValues(alpha: 0.15) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? UiTokens.accent : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              phase['name']!,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                color: isSelected ? Colors.white : UiTokens.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isCompleted
                                  ? UiTokens.success.withValues(alpha: 0.15)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCompleted ? UiTokens.success : Colors.white.withValues(alpha: 0.05),
                              ),
                            ),
                            child: Text(
                              '$checkedCount/$totalCount',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isCompleted ? UiTokens.success : UiTokens.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 32),
        // Right Checklist Panel
        Expanded(
          flex: 7,
          child: EfbGlassContainer(
            blur: 20,
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        phases.firstWhere((p) => p['id'] == selectedChecklistPhase)['name']!.toUpperCase(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          final ids = currentItems.map((item) => item.id).toList();
                          notifier.resetPhase(ids);
                        },
                        icon: const Icon(Icons.refresh, size: 16, color: UiTokens.error),
                        label: Text(
                          'RESET PHASE',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: UiTokens.error,
                            letterSpacing: 1,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      itemCount: currentItems.length,
                      itemBuilder: (context, index) {
                        final item = currentItems[index];
                        final isChecked = checklistState[item.id] ?? false;

                        return InkWell(
                          onTap: () => notifier.toggle(item.id),
                          borderRadius: BorderRadius.circular(12),
                          mouseCursor: SystemMouseCursors.click,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isChecked ? Colors.white.withValues(alpha: 0.02) : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Transform.scale(
                                    scale: 0.9,
                                    child: Checkbox(
                                      value: isChecked,
                                      onChanged: (_) => notifier.toggle(item.id),
                                      activeColor: UiTokens.accent,
                                      checkColor: Colors.white,
                                      side: BorderSide(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.item,
                                              style: GoogleFonts.plusJakartaSans(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isChecked ? UiTokens.textDim : Colors.white,
                                                decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Text(
                                            item.status,
                                            style: GoogleFonts.jetBrainsMono(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isChecked ? UiTokens.textDim : UiTokens.accent,
                                              decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                                            ),
                                          ),
                                        ],
                                      ),
                                      if (item.note != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.note!,
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: isChecked ? UiTokens.textDim.withValues(alpha: 0.5) : UiTokens.textDim,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ChecklistItem {
  final String id;
  final String item;
  final String status;
  final String? note;

  const ChecklistItem({
    required this.id,
    required this.item,
    required this.status,
    this.note,
  });
}
