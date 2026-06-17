import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../providers/efb_providers.dart';
import '../providers/badge_provider.dart';
import '../widgets/efb_card.dart';
import '../widgets/efb_text_field.dart';
import '../widgets/efb_launches_badge.dart';
import '../widgets/wind_arrow.dart';
import '../core/ui_tokens.dart';
import '../core/concorde_constants.dart';
import '../core/metar_parser.dart';
import '../models/concorde_models.dart';
import '../services/simbrief_service.dart';
import '../models/airport.dart';

final numFormat = NumberFormat('#,###');

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  // Local state for expanding METAR strings
  bool showDepRaw = false;
  bool showArrRaw = false;

  @override
  Widget build(BuildContext context) {
    final airportDbAsync = ref.watch(airportDbProvider);

    return airportDbAsync.when(
      loading: () => const Scaffold(
        backgroundColor: UiTokens.bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: UiTokens.accent),
              SizedBox(height: 24),
              Text('LOADING AIRPORT DATABASE...', style: TextStyle(color: UiTokens.textSecondary, letterSpacing: 3, fontWeight: FontWeight.w900)),
            ],
          ),
        ),
      ),
      error: (err, stack) => Scaffold(
        backgroundColor: UiTokens.bg,
        body: Center(
          child: Text('Error loading database: $err', style: const TextStyle(color: UiTokens.error)),
        ),
      ),
      data: (db) {
        return Scaffold(
          backgroundColor: UiTokens.bg,
          body: SafeArea(
            child: Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  // Force a minimum width to prevent any RenderFlex overflow issues
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
              const Text(
                'Concorde EFB',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              const Text(
                'Flight planning & performance for MSFS.',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: UiTokens.textSecondary),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildBadge('V2.1.0'),
                  const SizedBox(width: 8),
                  _buildBadge('BUILD 160626-3'),
                ],
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

  Widget _buildBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: UiTokens.textDim)),
    );
  }

  Widget _buildHeaderStat(String label, String value, {Color valueColor = Colors.white}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: UiTokens.textSecondary, letterSpacing: 1.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: valueColor, fontFamily: 'monospace')),
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
              SizedBox(
                height: 48,
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
                      }
                    } finally {
                      ref.read(simbriefLoadingProvider.notifier).set(false);
                    }
                  },
                  icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download, size: 16),
                  label: const Text('Import', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTokens.accent,
                    foregroundColor: Colors.white,
                    elevation: 10,
                    shadowColor: UiTokens.accent.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(child: _buildInfoChip('CALL SIGN', ref.watch(callSignProvider))),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoChip('REGISTRATION', ref.watch(registrationProvider))),
              const SizedBox(width: 16),
              Expanded(child: _buildInfoChip('PASSENGERS', '${ref.watch(paxCountProvider)}')),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${ref.watch(departureIcaoProvider)} → ${ref.watch(arrivalIcaoProvider)} (ALT: ${ref.watch(alternateIcaoProvider)})',
                    style: const TextStyle(color: UiTokens.textSecondary, fontFamily: 'monospace', fontSize: 14),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _buildInfoChip('ESTIMATED ROUTE DISTANCE', '${ref.watch(plannedDistanceProvider).round()} NM', alignLeft: true),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, String value, {bool alignLeft = false}) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: UiTokens.textDim, letterSpacing: 1)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: UiTokens.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildCruiseAndFuelSection(WidgetRef ref) {
    final fuel = ref.watch(fuelBreakdownProvider);
    final mission = ref.watch(missionProfileProvider);
    final weights = ref.watch(weightsProvider);
    final isOverCapacity = fuel.blockKg > ConcordeConstants.weights.fuelCapacityKg;
    final direction = ref.watch(flightDirectionProvider);

    return EfbCard(
      title: 'CRUISE & FUEL MANAGEMENT',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1 (Full Width): Times
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
            style: const TextStyle(color: UiTokens.textDim, fontSize: 10),
          ),
          const SizedBox(height: 32),
          // Bottom Section: Split
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: Inputs + Advanced + Stats
              Expanded(
                flex: 13,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Distance & FL Inputs
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
                                style: const TextStyle(color: UiTokens.textDim, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('ADVANCED', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: UiTokens.textPrimary, letterSpacing: 2)),
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
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        Expanded(child: _buildBottomStatBox('COMPUTED TOW', '${numFormat.format(weights['TOW']!.round())} kg', isLarge: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBottomStatBox('FUEL ENDURANCE', _formatHoursMinutes(fuel.blockKg / 40000))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBottomStatBox('ETE + RESERVES', _formatHoursMinutes(mission.totalTimeH + (fuel.finalReserveKg / 40000)))),
                        const SizedBox(width: 12),
                        Expanded(child: _buildBottomStatBox('PASSENGERS', '${ref.watch(paxCountProvider)} pax', subtext: '${numFormat.format(weights['PAX']!.round())} kg @ 84 kg each')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 32),
              // Right Column: Fuel Strip
              Expanded(
                flex: 7,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFuelRow('Trip Fuel', fuel.tripKg),
                      _buildDivider(),
                      _buildFuelRow('Taxi Fuel', fuel.taxiKg),
                      _buildDivider(),
                      _buildFuelRow('Contingency', fuel.contingencyKg),
                      _buildDivider(),
                      _buildFuelRow('Trim Fuel', ref.watch(trimTankFuelProvider)),
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
                              const Text('Total Required', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: UiTokens.textPrimary)),
                              const SizedBox(height: 4),
                              Text('Block + Trim (0 kg)', style: TextStyle(fontSize: 10, color: UiTokens.textSecondary.withValues(alpha: 0.5))),
                            ],
                          ),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(numFormat.format(fuel.blockKg + ref.watch(trimTankFuelProvider)), style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isOverCapacity ? UiTokens.error : UiTokens.success, fontFamily: 'monospace')),
                              const SizedBox(width: 4),
                              const Text('kg', style: TextStyle(fontSize: 14, color: UiTokens.textSecondary)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Warning/Alert messages
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reheat safety: climb reheat within ${ConcordeConstants.fuel.reheatMinutesCap} min cap.',
                style: TextStyle(
                  color: mission.climb.timeH * 60 <= ConcordeConstants.fuel.reheatMinutesCap ? UiTokens.textDim : UiTokens.error,
                  fontSize: 12,
                ),
              ),
              if (fuel.blockKg < (mission.totalTimeH + (fuel.finalReserveKg / 40000)) * 40000)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Fuel endurance is less than required ETE + reserves.',
                    style: TextStyle(color: UiTokens.error, fontSize: 12),
                  ),
                ),
              if (isOverCapacity)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Warning: Total fuel exceeds Concorde fuel capacity of ${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg.',
                    style: const TextStyle(color: UiTokens.error, fontSize: 12, fontWeight: FontWeight.bold),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: UiTokens.textDim, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: const TextStyle(fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.w900),
              children: [
                TextSpan(text: '$h', style: const TextStyle(fontSize: 22)),
                const TextSpan(text: ' h ', style: TextStyle(fontSize: 12, color: UiTokens.textSecondary, fontWeight: FontWeight.w600)),
                TextSpan(text: m.toString().padLeft(2, '0'), style: const TextStyle(fontSize: 22)),
                const TextSpan(text: ' m', style: TextStyle(fontSize: 12, color: UiTokens.textSecondary, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatBox(String label, String value, {bool isLarge = false, String? subtext}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withValues(alpha: 0.05))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: UiTokens.textDim, letterSpacing: 1), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: isLarge ? 18 : 16, fontWeight: FontWeight.w900, color: Colors.white, fontFamily: 'monospace')),
          if (subtext != null) ...[
            const SizedBox(height: 4),
            Text(subtext, style: const TextStyle(fontSize: 10, color: UiTokens.textDim, fontWeight: FontWeight.w500)),
          ],
        ],
      ),
    );
  }

  Widget _buildFuelRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: isBold ? Colors.white : UiTokens.textSecondary)),
          Text(numFormat.format(value.round()), style: TextStyle(fontSize: isBold ? 18 : 16, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
        ],
      ),
    );
  }

  Widget _buildDivider() => const Divider(color: Colors.white10, height: 16);

  Widget _buildPerformanceCalculatorSection(WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PERFORMANCE CALCULATOR', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1)),
          const SizedBox(height: 32),
          const Text('Airports & Runways', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
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
    );
  }

  Widget _buildRunwayDropdown(WidgetRef ref, String label, Airport? airport, String currentId, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: UiTokens.textSecondary, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentId.isEmpty ? null : currentId,
              items: airport?.runways.map((r) => DropdownMenuItem(value: r.id, child: Text('RWY ${r.id} • ${numFormat.format(r.lengthM)} m • ${r.heading}°'))).toList() ?? [],
              onChanged: onChanged,
              dropdownColor: const Color(0xFF1E293B),
              style: const TextStyle(color: UiTokens.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
              isExpanded: true,
              hint: const Text('Select...', style: TextStyle(color: UiTokens.textDim)),
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
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: catColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: UiTokens.textSecondary, letterSpacing: 2)),
                    const SizedBox(width: 8),
                    Icon(showRaw ? Icons.expand_less : Icons.expand_more, size: 16, color: UiTokens.textDim),
                  ],
                ),
                Row(
                  children: [
                    Text('$summary • ${tempC?.round() ?? '--'}°C', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: UiTokens.textSecondary, letterSpacing: 1)),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: catColor, width: 1.5)),
                      child: Text(cat, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: catColor)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (showRaw && metarStr.isNotEmpty) ...[
              Text(metarStr, style: const TextStyle(fontSize: 14, fontFamily: 'monospace', color: Colors.white, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
                  children: [
                    WindArrow(runwayHeading: rwyHeading, windDir: parsed.windDirDeg, color: UiTokens.accent, size: 56),
                    const SizedBox(height: 8),
                    Text(runway?.id ?? '--', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildMetarChip('WIND', '${parsed.windDirDeg?.round() ?? 'VRB'}° ${parsed.windSpeedKt?.round() ?? '--'} kt'),
                      _buildMetarChip('VIS', '${vis != null ? (vis >= 10 ? '10+' : vis.toStringAsFixed(1)) : '--'} km'),
                      _buildMetarChip('QNH', '${qnh?.value.round() ?? '--'} ${qnh?.unit ?? ''}'),
                      if (runway != null) _buildMetarChip('RWY ELEV', '${runway.elevationFt?.round() ?? '--'} ft'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetarChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: UiTokens.textDim, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildPerfCard(WidgetRef ref, String title, double weightKg, Map<String, double> speeds, RunwayFeasibility? f) {
    final bool isFeasible = f?.feasible ?? true;
    final String reqRunway = f != null ? numFormat.format(f.requiredLengthMEst.round()) : '--';
    final Color tintColor = isFeasible ? UiTokens.surface : UiTokens.error;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: tintColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (isFeasible ? Colors.white : UiTokens.error).withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 2)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: (isFeasible ? UiTokens.vfr : UiTokens.error).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(16), border: Border.all(color: (isFeasible ? UiTokens.vfr : UiTokens.error).withValues(alpha: 0.5))),
                child: Text(isFeasible ? 'WITHIN LIMITS' : 'EXCEEDS LIMITS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: isFeasible ? UiTokens.vfr : UiTokens.error, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(numFormat.format(weightKg.round()), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.white)),
              const SizedBox(width: 4),
              const Text('kg', style: TextStyle(fontSize: 14, color: UiTokens.textSecondary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: speeds.entries.map((e) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(e.key, style: const TextStyle(fontSize: 12, color: UiTokens.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(e.value.round().toString(), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white)),
                  ],
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
          Text('Runway required: $reqRunway m', style: const TextStyle(fontSize: 14, color: UiTokens.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Column(
      children: [
        SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EfbLaunchesBadge(),
          ],
        ),
        SizedBox(height: 24),
        Text('Speeds scale with √(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim.', style: TextStyle(color: UiTokens.textDim, fontSize: 12)),
      ],
    );
  }
}
