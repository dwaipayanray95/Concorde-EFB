import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../widgets/wind_arrow.dart';
import '../../../widgets/efb_glass_container.dart';
import '../../../core/ui_tokens.dart';
import '../../../core/concorde_constants.dart';
import '../../../core/metar_parser.dart';
import '../../../core/formatters.dart';
import '../../../models/concorde_models.dart';
import '../../../models/airport.dart';

/// PERFORMANCE CALCULATOR card: airport/runway selection, METAR readouts,
/// and takeoff/landing performance feasibility cards.
class PerformanceCalculatorSection extends ConsumerStatefulWidget {
  const PerformanceCalculatorSection({super.key});

  @override
  ConsumerState<PerformanceCalculatorSection> createState() => _PerformanceCalculatorSectionState();
}

class _PerformanceCalculatorSectionState extends ConsumerState<PerformanceCalculatorSection> {
  bool showDepRaw = false;
  bool showArrRaw = false;

  @override
  Widget build(BuildContext context) {
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
                Expanded(child: _RunwayDropdown(label: 'DEPARTURE RUNWAY', airport: ref.watch(depAirportProvider), currentId: ref.watch(departureRunwayIdProvider), onChanged: (v) => ref.read(departureRunwayIdProvider.notifier).set(v ?? ''))),
                const SizedBox(width: 32),
                Expanded(child: EfbTextField(label: 'ARRIVAL ICAO', initialValue: ref.watch(arrivalIcaoProvider), onChanged: (v) => ref.read(arrivalIcaoProvider.notifier).set(v))),
                const SizedBox(width: 16),
                Expanded(child: _RunwayDropdown(label: 'ARRIVAL RUNWAY', airport: ref.watch(arrAirportProvider), currentId: ref.watch(arrivalRunwayIdProvider), onChanged: (v) => ref.read(arrivalRunwayIdProvider.notifier).set(v ?? ''))),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ref.watch(departureMetarFutureProvider).when(
                    data: (metar) => _MetarDisplay(title: 'DEP METAR', metarStr: metar, runway: ref.watch(departureRunwayProvider), showRaw: showDepRaw, onToggle: () => setState(() => showDepRaw = !showDepRaw)),
                    loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                    error: (error, stack) => _MetarDisplay(title: 'DEP METAR', metarStr: '', runway: ref.watch(departureRunwayProvider), showRaw: showDepRaw, onToggle: () => setState(() => showDepRaw = !showDepRaw)),
                  ),
                ),
                const SizedBox(width: 32),
                Expanded(
                  child: ref.watch(arrivalMetarFutureProvider).when(
                    data: (metar) => _MetarDisplay(title: 'ARR METAR', metarStr: metar, runway: ref.watch(arrivalRunwayProvider), showRaw: showArrRaw, onToggle: () => setState(() => showArrRaw = !showArrRaw)),
                    loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
                    error: (error, stack) => _MetarDisplay(title: 'ARR METAR', metarStr: '', runway: ref.watch(arrivalRunwayProvider), showRaw: showArrRaw, onToggle: () => setState(() => showArrRaw = !showArrRaw)),
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
                Expanded(child: _PerfCard(title: 'TAKEOFF PERFORMANCE', weightKg: ref.watch(weightsProvider)['TOW']!, speeds: ref.watch(takeoffSpeedsProvider), feasibility: ref.watch(takeoffFeasibilityProvider))),
                const SizedBox(width: 32),
                Expanded(child: _PerfCard(title: 'LANDING PERFORMANCE', weightKg: ref.watch(weightsProvider)['LW']!, speeds: ref.watch(landingSpeedsProvider), feasibility: ref.watch(landingFeasibilityProvider))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RunwayDropdown extends StatelessWidget {
  final String label;
  final Airport? airport;
  final String currentId;
  final ValueChanged<String?> onChanged;

  const _RunwayDropdown({required this.label, required this.airport, required this.currentId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
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
}

class _MetarDisplay extends ConsumerWidget {
  final String title;
  final String metarStr;
  final Runway? runway;
  final bool showRaw;
  final VoidCallback onToggle;

  const _MetarDisplay({required this.title, required this.metarStr, required this.runway, required this.showRaw, required this.onToggle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                          if (showRaw)
                            Text(
                              metarStr,
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 13,
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          else
                            Text(
                              'TAP TO SHOW RAW METAR',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 9,
                                color: UiTokens.textDim,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1,
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _MetarChip(label: 'WIND', value: '${parsed.windDirDeg?.round() ?? 'VRB'}° ${parsed.windSpeedKt?.round() ?? '--'} kt'),
                            _MetarChip(label: 'VIS', value: '${vis != null ? (vis >= 10 ? '10+' : vis.toStringAsFixed(1)) : '--'} km'),
                            _MetarChip(label: 'QNH', value: '${qnh?.value.round() ?? '--'} ${qnh?.unit ?? ''}'),
                            if (runway != null) _MetarChip(label: 'RWY ELEV', value: '${runway!.elevationFt?.round() ?? '--'} ft'),
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
}

class _MetarChip extends StatelessWidget {
  final String label;
  final String value;
  const _MetarChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
}

class _PerfCard extends ConsumerWidget {
  final String title;
  final double weightKg;
  final Map<String, double> speeds;
  final RunwayFeasibility? feasibility;

  const _PerfCard({required this.title, required this.weightKg, required this.speeds, required this.feasibility});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final f = feasibility;
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
}
