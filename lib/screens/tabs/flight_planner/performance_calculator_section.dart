import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/wind_arrow.dart';
import '../../../core/concorde_constants.dart';
import '../../../core/metar_parser.dart';
import '../../../core/formatters.dart';
import '../../../models/concorde_models.dart';
import '../../../models/airport.dart';

/// Light-theme palette for the Performance Calculator, matching the
/// "Performance Calculator Redesign v2" mockup exactly -- deliberately
/// separate from the rest of the app's dark [UiTokens] palette, since this
/// section is implemented as its own light "island" per that design.
class _Pc {
  static const bg = Color(0xFFF2F4FC);
  static const card = Color(0xFFFFFFFF);
  static const resultsBg = Color(0xFFF8F9FF);
  static const inputBg = Color(0xFFF2F4FC);
  static const textPrimary = Color(0xFF1A1C2E);
  static const textSecondary = Color(0xFF6B6F8A);
  static const textDim = Color(0xFF8A8DA8);
  static const divider = Color(0xFFEEF0FA);
  static const dividerStrong = Color(0xFFE4E7F5);
  static const accent = Color(0xFF3D5AFE);
  static const departure = Color(0xFFFF3D57);
  static const arrival = Color(0xFF00C853);
  static const errorBg = Color(0xFFFFEBEE);
  static const error = Color(0xFFD50032);
  static const successBg = Color(0xFFE4F9EE);
  static const success = Color(0xFF00A651);
  static const mvfrBg = Color(0xFFFFF4E0);
  static const mvfr = Color(0xFFFF9800);
  static const ifrBg = Color(0xFFFFE8E0);
  static const ifr = Color(0xFFFF5722);
}

TextStyle _pcSans({double size = 12, FontWeight weight = FontWeight.w400, Color color = _Pc.textPrimary, double letterSpacing = 0}) =>
    GoogleFonts.roboto(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

TextStyle _pcMono({double size = 12, FontWeight weight = FontWeight.w700, Color color = _Pc.textPrimary}) =>
    GoogleFonts.robotoMono(fontSize: size, fontWeight: weight, color: color);

/// PERFORMANCE CALCULATOR: one card per leg (departure/takeoff, arrival/
/// landing), each with an identity strip, ICAO+runway inputs, a live METAR
/// weather strip, and a results strip (TOW/LW, V-speeds, runway margin).
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
    return Container(
      decoration: BoxDecoration(color: _Pc.bg, borderRadius: BorderRadius.circular(24)),
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _Pc.accent,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: _Pc.accent.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))],
                ),
                child: const Icon(Icons.flight_takeoff, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 14),
              Text('Performance Calculator', style: _pcSans(size: 22, weight: FontWeight.w900, letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 28),
          _LegCard(
            legLabel: 'DEPARTURE / TAKEOFF',
            accent: _Pc.departure,
            icao: ref.watch(departureIcaoProvider),
            onIcaoChanged: (v) => ref.read(departureIcaoProvider.notifier).set(v),
            airport: ref.watch(depAirportProvider),
            currentRunwayId: ref.watch(departureRunwayIdProvider),
            onRunwayChanged: (v) => ref.read(departureRunwayIdProvider.notifier).set(v ?? ''),
            runway: ref.watch(departureRunwayProvider),
            metarAsync: ref.watch(departureMetarFutureProvider),
            onRefreshMetar: () => ref.invalidate(departureMetarFutureProvider),
            showRaw: showDepRaw,
            onToggleRaw: () => setState(() => showDepRaw = !showDepRaw),
            weightKg: ref.watch(weightsProvider)['TOW']!,
            weightLabel: 'TOW',
            speeds: ref.watch(takeoffSpeedsProvider),
            speedColor: _Pc.accent,
            feasibility: ref.watch(takeoffFeasibilityProvider),
            maxWeightKg: ConcordeConstants.weights.mtowKg,
            noReheatFeasibility: ref.watch(takeoffFeasibilityNoReheatProvider),
          ),
          const SizedBox(height: 24),
          _LegCard(
            legLabel: 'ARRIVAL / LANDING',
            accent: _Pc.arrival,
            icao: ref.watch(arrivalIcaoProvider),
            onIcaoChanged: (v) => ref.read(arrivalIcaoProvider.notifier).set(v),
            airport: ref.watch(arrAirportProvider),
            currentRunwayId: ref.watch(arrivalRunwayIdProvider),
            onRunwayChanged: (v) => ref.read(arrivalRunwayIdProvider.notifier).set(v ?? ''),
            runway: ref.watch(arrivalRunwayProvider),
            metarAsync: ref.watch(arrivalMetarFutureProvider),
            onRefreshMetar: () => ref.invalidate(arrivalMetarFutureProvider),
            showRaw: showArrRaw,
            onToggleRaw: () => setState(() => showArrRaw = !showArrRaw),
            weightKg: ref.watch(weightsProvider)['LW']!,
            weightLabel: 'LW',
            speeds: ref.watch(landingSpeedsProvider),
            speedColor: _Pc.success,
            feasibility: ref.watch(landingFeasibilityProvider),
            maxWeightKg: ConcordeConstants.weights.mlwKg,
          ),
        ],
      ),
    );
  }
}

class _LegCard extends ConsumerWidget {
  final String legLabel;
  final Color accent;
  final String icao;
  final ValueChanged<String> onIcaoChanged;
  final Airport? airport;
  final String currentRunwayId;
  final ValueChanged<String?> onRunwayChanged;
  final Runway? runway;
  final AsyncValue<String> metarAsync;
  final VoidCallback onRefreshMetar;
  final bool showRaw;
  final VoidCallback onToggleRaw;
  final double weightKg;
  final String weightLabel;
  final Map<String, double> speeds;
  final Color speedColor;
  final RunwayFeasibility? feasibility;
  final double maxWeightKg;
  final RunwayFeasibility? noReheatFeasibility;

  const _LegCard({
    required this.legLabel,
    required this.accent,
    required this.icao,
    required this.onIcaoChanged,
    required this.airport,
    required this.currentRunwayId,
    required this.onRunwayChanged,
    required this.runway,
    required this.metarAsync,
    required this.onRefreshMetar,
    required this.showRaw,
    required this.onToggleRaw,
    required this.weightKg,
    required this.weightLabel,
    required this.speeds,
    required this.speedColor,
    required this.feasibility,
    required this.maxWeightKg,
    this.noReheatFeasibility,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalFuel = ref.watch(weightsProvider)['FUEL'] ?? 0.0;
    final isFuelOver = totalFuel > ConcordeConstants.weights.fuelCapacityKg;
    final isWeightFeasible = weightKg <= maxWeightKg;
    final isFeasible = (feasibility?.feasible ?? true) && isWeightFeasible && !isFuelOver;

    return Container(
      decoration: BoxDecoration(
        color: _Pc.card,
        borderRadius: BorderRadius.circular(20),
        border: Border(top: BorderSide(color: accent, width: 5)),
        boxShadow: [
          BoxShadow(color: _Pc.textPrimary.withValues(alpha: 0.08), blurRadius: 24, offset: const Offset(0, 4)),
          BoxShadow(color: _Pc.textPrimary.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Strip 1: identity row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _Pc.divider))),
            child: Row(
              children: [
                Icon(Icons.flight_takeoff, size: 18, color: accent),
                const SizedBox(width: 10),
                Text(legLabel, style: _pcSans(size: 12, weight: FontWeight.w900, color: _Pc.textSecondary, letterSpacing: 2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: isFeasible ? _Pc.successBg : _Pc.errorBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFeasible ? 'WITHIN LIMITS' : 'EXCEEDS LIMITS',
                    style: _pcSans(size: 11, weight: FontWeight.w800, color: isFeasible ? _Pc.success : _Pc.error, letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ),
          // Strip 2: airport inputs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _Pc.divider))),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _IcaoField(value: icao, onChanged: onIcaoChanged)),
                const SizedBox(width: 16),
                Expanded(flex: 2, child: _RunwaySelect(airport: airport, currentId: currentRunwayId, onChanged: onRunwayChanged)),
              ],
            ),
          ),
          // Strip 3: weather
          metarAsync.when(
            data: (metar) => _WeatherStrip(
              metarStr: metar,
              runway: runway,
              showRaw: showRaw,
              onToggleRaw: onToggleRaw,
              onRefresh: onRefreshMetar,
            ),
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(child: CircularProgressIndicator(color: _Pc.accent)),
            ),
            error: (_, _) => _WeatherStrip(
              metarStr: '',
              runway: runway,
              showRaw: showRaw,
              onToggleRaw: onToggleRaw,
              onRefresh: onRefreshMetar,
            ),
          ),
          // Strip 4: results
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            color: _Pc.resultsBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(text: numFormat.format(weightKg.round()), style: _pcMono(size: 28, weight: FontWeight.w900)),
                      TextSpan(text: ' kg $weightLabel', style: _pcSans(size: 13, weight: FontWeight.w700, color: _Pc.textDim)),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Container(width: 1, height: 36, color: _Pc.dividerStrong),
                const SizedBox(width: 28),
                Row(
                  children: speeds.entries.map((e) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(e.key, style: _pcSans(size: 10, weight: FontWeight.w700, color: _Pc.textDim)),
                          const SizedBox(height: 5),
                          Text(e.value.round().toString(), style: _pcMono(size: 22, weight: FontWeight.w900, color: speedColor)),
                        ],
                      ),
                    );
                  }).toList(),
                ),
                Expanded(
                  child: _RunwayMarginText(
                    feasibility: feasibility,
                    isWeightFeasible: isWeightFeasible,
                    isFuelOver: isFuelOver,
                    maxWeightKg: maxWeightKg,
                    noReheatFeasible: noReheatFeasibility?.feasible ?? false,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IcaoField extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _IcaoField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ICAO', style: _pcSans(size: 10, weight: FontWeight.w700, color: _Pc.textDim, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: _Pc.inputBg, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: TextEditingController(text: value)..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            textCapitalization: TextCapitalization.characters,
            style: _pcMono(size: 17, weight: FontWeight.w700),
            decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
          ),
        ),
      ],
    );
  }
}

class _RunwaySelect extends StatelessWidget {
  final Airport? airport;
  final String currentId;
  final ValueChanged<String?> onChanged;
  const _RunwaySelect({required this.airport, required this.currentId, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RUNWAY', style: _pcSans(size: 10, weight: FontWeight.w700, color: _Pc.textDim, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(color: _Pc.inputBg, borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 44,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentId.isEmpty ? null : currentId,
              items: airport?.runways
                      .map((r) => DropdownMenuItem(
                            value: r.id,
                            child: Text('RWY ${r.id} • ${numFormat.format(r.lengthM)} m • ${r.heading}°', style: _pcMono(size: 14, weight: FontWeight.w700)),
                          ))
                      .toList() ??
                  [],
              onChanged: onChanged,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18, color: _Pc.textDim),
              hint: Text('Select...', style: _pcSans(size: 13, color: _Pc.textDim)),
              dropdownColor: _Pc.card,
              style: _pcMono(size: 14, weight: FontWeight.w700),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeatherStrip extends StatelessWidget {
  final String metarStr;
  final Runway? runway;
  final bool showRaw;
  final VoidCallback onToggleRaw;
  final VoidCallback onRefresh;

  const _WeatherStrip({required this.metarStr, required this.runway, required this.showRaw, required this.onToggleRaw, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final parsed = MetarParser.parseWind(metarStr);
    final qnh = MetarParser.parseQnh(metarStr);
    final tempC = MetarParser.parseTempC(metarStr);
    final vis = MetarParser.parseVisibilityKm(metarStr);
    final cat = MetarParser.parseFlightCategory(metarStr);
    final summary = MetarParser.parseWeatherSummary(metarStr);
    final rwyHeading = runway?.heading.toDouble();

    Color catBg = _Pc.successBg;
    Color catColor = _Pc.success;
    if (cat == 'MVFR') {
      catBg = _Pc.mvfrBg;
      catColor = _Pc.mvfr;
    } else if (cat == 'IFR') {
      catBg = _Pc.ifrBg;
      catColor = _Pc.ifr;
    } else if (cat == 'LIFR') {
      catBg = _Pc.errorBg;
      catColor = _Pc.error;
    }

    return InkWell(
      onTap: metarStr.isNotEmpty ? onToggleRaw : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: _Pc.divider))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: _Pc.divider, borderRadius: BorderRadius.circular(12)),
                  child: Center(
                    child: WindArrow(runwayHeading: rwyHeading, windDir: parsed.windDirDeg, windSpeedKt: parsed.windSpeedKt, color: _Pc.accent, size: 26),
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
                  decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(20)),
                  child: Text(cat, style: _pcSans(size: 10, weight: FontWeight.w800, color: catColor, letterSpacing: 0.5)),
                ),
                const SizedBox(width: 20),
                Text('${tempC?.round() ?? '--'}°C, $summary', style: _pcSans(size: 12, weight: FontWeight.w700, color: _Pc.textSecondary)),
                const SizedBox(width: 20),
                Container(width: 1, height: 20, color: _Pc.dividerStrong),
                const SizedBox(width: 20),
                Expanded(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _WeatherStat(label: 'WIND', value: '${parsed.windDirDeg?.round() ?? 'VRB'}° ${parsed.windSpeedKt?.round() ?? '--'}kt'),
                      _WeatherStat(label: 'VIS', value: '${vis != null ? (vis >= 10 ? '10+' : vis.toStringAsFixed(1)) : '--'}km'),
                      _WeatherStat(label: 'QNH', value: '${qnh?.value.round() ?? '--'}${qnh?.unit ?? ''}'),
                      _WeatherStat(label: 'ELEV', value: '${runway?.elevationFt?.round() ?? '--'}ft'),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 16, color: _Pc.accent),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onRefresh,
                ),
              ],
            ),
            if (metarStr.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                showRaw ? metarStr : 'TAP TO SHOW RAW METAR',
                style: showRaw
                    ? _pcMono(size: 12, weight: FontWeight.w500, color: _Pc.textSecondary)
                    : _pcSans(size: 9, weight: FontWeight.w700, color: _Pc.textDim, letterSpacing: 1),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeatherStat extends StatelessWidget {
  final String label;
  final String value;
  const _WeatherStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: _pcSans(size: 10, weight: FontWeight.w700, color: _Pc.textDim)),
        Text(value, style: _pcMono(size: 12, weight: FontWeight.w700)),
      ],
    );
  }
}

class _RunwayMarginText extends StatelessWidget {
  final RunwayFeasibility? feasibility;
  final bool isWeightFeasible;
  final bool isFuelOver;
  final double maxWeightKg;
  final bool noReheatFeasible;

  const _RunwayMarginText({
    required this.feasibility,
    required this.isWeightFeasible,
    required this.isFuelOver,
    required this.maxWeightKg,
    this.noReheatFeasible = false,
  });

  @override
  Widget build(BuildContext context) {
    final f = feasibility;
    if (!isWeightFeasible) {
      return Text(
        'EXCEEDS MAX WEIGHT (${numFormat.format(maxWeightKg)} kg)',
        textAlign: TextAlign.right,
        style: _pcSans(size: 12, weight: FontWeight.w800, color: _Pc.error),
      );
    }
    if (isFuelOver) {
      return Text(
        'EXCEEDS FUEL CAPACITY (${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg)',
        textAlign: TextAlign.right,
        style: _pcSans(size: 12, weight: FontWeight.w800, color: _Pc.error),
      );
    }
    if (f == null) {
      return Text('--', textAlign: TextAlign.right, style: _pcSans(size: 12, color: _Pc.textSecondary));
    }
    final reqRunway = numFormat.format(f.requiredLengthMEst.round());
    final availRunway = numFormat.format(f.runwayLengthM.round());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          textAlign: TextAlign.right,
          text: TextSpan(
            style: _pcSans(size: 12, color: _Pc.textSecondary),
            children: [
              const TextSpan(text: 'Runway required '),
              TextSpan(text: '$reqRunway m', style: _pcSans(size: 12, weight: FontWeight.w800, color: f.feasible ? _Pc.success : _Pc.error)),
              TextSpan(text: ' vs $availRunway m avail'),
            ],
          ),
        ),
        if (noReheatFeasible) ...[
          const SizedBox(height: 4),
          Text(
            'Takeoff possible without reheat',
            style: _pcSans(size: 11, weight: FontWeight.w700, color: _Pc.success),
          ),
        ],
      ],
    );
  }
}
