import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../providers/efb_providers.dart';
import '../providers/badge_provider.dart';
import '../widgets/efb_card.dart';
import '../widgets/efb_text_field.dart';
import '../widgets/efb_launches_badge.dart';
import '../widgets/wind_arrow.dart';
import '../widgets/efb_glass_container.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool showDepRaw = false;
  bool showArrRaw = false;

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
                Scrollbar(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: MediaQuery.of(context).size.width > 1080 ? MediaQuery.of(context).size.width : 1080,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(ref),
                            const SizedBox(height: 48),
                            _buildFlightPlanAndCruiseRow(ref),
                            const SizedBox(height: 32),
                            _buildPerformanceCalculatorSection(ref),
                            const SizedBox(height: 64),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                  ),
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
    return Row(
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
                                'Direction (auto): ${direction == "E" ? "Eastbound" : direction == "W" ? "Westbound" : "unknown"}. Above FL410 we snap to Non-RVSM levels.',
                                style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 10),
                              ),
                            ],
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
            const SizedBox(height: 32),
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
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w900, color: UiTokens.textSecondary, letterSpacing: 2),
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
      ],
    );
  }
}
