import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/wind_arrow.dart';
import '../../../widgets/efb_card.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../core/concorde_constants.dart';
import '../../../core/metar_parser.dart';
import '../../../core/formatters.dart';
import '../../../models/concorde_models.dart';
import '../../../models/airport.dart';

/// PERFORMANCE CALCULATOR: one card per leg (departure/takeoff, arrival/
/// landing), each with an identity strip, ICAO+runway inputs, a live METAR
/// weather strip, and a results strip (TOW/LW, V-speeds, runway margin).
class PerformanceCalculatorSection extends ConsumerStatefulWidget {
  const PerformanceCalculatorSection({super.key});

  @override
  ConsumerState<PerformanceCalculatorSection> createState() =>
      _PerformanceCalculatorSectionState();
}

class _PerformanceCalculatorSectionState
    extends ConsumerState<PerformanceCalculatorSection> {
  bool showDepRaw = false;
  bool showArrRaw = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return EfbCard(
      title: 'PERFORMANCE CALCULATOR',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _LegCard(
            legLabel: 'DEPARTURE / TAKEOFF',
            accent: colors.departure,
            icao: ref.watch(departureIcaoProvider),
            onIcaoChanged:
                (v) => ref.read(departureIcaoProvider.notifier).set(v),
            airport: ref.watch(depAirportProvider),
            currentRunwayId: ref.watch(departureRunwayIdProvider),
            onRunwayChanged:
                (v) =>
                    ref.read(departureRunwayIdProvider.notifier).set(v ?? ''),
            runway: ref.watch(departureRunwayProvider),
            metarAsync: ref.watch(departureMetarFutureProvider),
            onRefreshMetar: () => ref.invalidate(departureMetarFutureProvider),
            showRaw: showDepRaw,
            onToggleRaw: () => setState(() => showDepRaw = !showDepRaw),
            weightKg: ref.watch(weightsProvider)['TOW']!,
            weightLabel: 'TOW',
            speeds: ref.watch(takeoffSpeedsProvider),
            speedColor: colors.accent,
            feasibility: ref.watch(takeoffFeasibilityProvider),
            maxWeightKg: ConcordeConstants.weights.mtowKg,
            noReheatFeasibility: ref.watch(takeoffFeasibilityNoReheatProvider),
          ),
          const SizedBox(height: 24),
          _LegCard(
            legLabel: 'ARRIVAL / LANDING',
            accent: colors.arrival,
            icao: ref.watch(arrivalIcaoProvider),
            onIcaoChanged: (v) => ref.read(arrivalIcaoProvider.notifier).set(v),
            airport: ref.watch(arrAirportProvider),
            currentRunwayId: ref.watch(arrivalRunwayIdProvider),
            onRunwayChanged:
                (v) => ref.read(arrivalRunwayIdProvider.notifier).set(v ?? ''),
            runway: ref.watch(arrivalRunwayProvider),
            metarAsync: ref.watch(arrivalMetarFutureProvider),
            onRefreshMetar: () => ref.invalidate(arrivalMetarFutureProvider),
            showRaw: showArrRaw,
            onToggleRaw: () => setState(() => showArrRaw = !showArrRaw),
            weightKg: ref.watch(weightsProvider)['LW']!,
            weightLabel: 'LW',
            speeds: ref.watch(landingSpeedsProvider),
            speedColor: colors.arrival,
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
    final colors = context.colors;
    final totalFuel = ref.watch(weightsProvider)['FUEL'] ?? 0.0;
    final isFuelOver = totalFuel > ConcordeConstants.weights.fuelCapacityKg;
    final isWeightFeasible = weightKg <= maxWeightKg;
    final isFeasible =
        (feasibility?.feasible ?? true) && isWeightFeasible && !isFuelOver;

    return Container(
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.dividerStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top accent strip that conforms to rounded corners
          Container(height: 4, color: accent),
          // Strip 1: identity row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: colors.resultsBg,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Icon(Icons.flight_takeoff, size: 18, color: accent),
                const SizedBox(width: 10),
                Text(
                  legLabel,
                  style: uiText(
                    context,
                    size: 12,
                    weight: FontWeight.w900,
                    color: colors.textSecondary,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isFeasible ? colors.successBg : colors.errorBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isFeasible ? 'WITHIN LIMITS' : 'EXCEEDS LIMITS',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w800,
                      color: isFeasible ? colors.success : colors.error,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Strip 2: airport inputs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _IcaoField(value: icao, onChanged: onIcaoChanged),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 2,
                  child: _RunwaySelect(
                    airport: airport,
                    currentId: currentRunwayId,
                    onChanged: onRunwayChanged,
                  ),
                ),
              ],
            ),
          ),
          // Strip 3: weather
          metarAsync.when(
            data:
                (metar) => _WeatherStrip(
                  metarStr: metar,
                  runway: runway,
                  showRaw: showRaw,
                  onToggleRaw: onToggleRaw,
                  onRefresh: onRefreshMetar,
                ),
            loading:
                () => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: CircularProgressIndicator(color: colors.accent),
                  ),
                ),
            error:
                (_, _) => _WeatherStrip(
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
            color: colors.resultsBg,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: numFormat.format(weightKg.round()),
                        style: uiText(
                          context,
                          size: 28,
                          weight: FontWeight.w900,
                          color: colors.textPrimary,
                        ),
                      ),
                      TextSpan(
                        text: ' kg $weightLabel',
                        style: uiText(
                          context,
                          size: 13,
                          weight: FontWeight.w700,
                          color: colors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 28),
                Container(width: 1, height: 36, color: colors.dividerStrong),
                const SizedBox(width: 28),
                Row(
                  children:
                      speeds.entries.map((e) {
                        return Padding(
                          padding: const EdgeInsets.only(right: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                e.key,
                                style: uiText(
                                  context,
                                  size: 10,
                                  weight: FontWeight.w700,
                                  color: colors.textDim,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                e.value.round().toString(),
                                style: uiText(
                                  context,
                                  size: 22,
                                  weight: FontWeight.w900,
                                  color: speedColor,
                                ),
                              ),
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
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ICAO',
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: colors.textDim,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller:
                TextEditingController(text: value)
                  ..selection = TextSelection.collapsed(offset: value.length),
            onChanged: onChanged,
            textCapitalization: TextCapitalization.characters,
            style: uiText(
              context,
              size: 17,
              weight: FontWeight.w700,
              color: colors.textPrimary,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8),
            ),
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
  const _RunwaySelect({
    required this.airport,
    required this.currentId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RUNWAY',
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: colors.textDim,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.inputBg,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          height: 44,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentId.isEmpty ? null : currentId,
              items:
                  airport?.runways
                      .map(
                        (r) => DropdownMenuItem(
                          value: r.id,
                          child: Text(
                            'RWY ${r.id} • ${numFormat.format(r.lengthM)} m • ${r.heading}°',
                            style: uiText(
                              context,
                              size: 14,
                              weight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList() ??
                  [],
              onChanged: onChanged,
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                size: 18,
                color: colors.textDim,
              ),
              hint: Text(
                'Select...',
                style: uiText(context, size: 13, color: colors.textDim),
              ),
              dropdownColor: colors.surface,
              style: uiText(
                context,
                size: 14,
                weight: FontWeight.w700,
                color: colors.textPrimary,
              ),
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

  const _WeatherStrip({
    required this.metarStr,
    required this.runway,
    required this.showRaw,
    required this.onToggleRaw,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final parsed = MetarParser.parseWind(metarStr);
    final qnh = MetarParser.parseQnh(metarStr);
    final tempC = MetarParser.parseTempC(metarStr);
    final vis = MetarParser.parseVisibilityKm(metarStr);
    final cat = MetarParser.parseFlightCategory(metarStr);
    final summary = MetarParser.parseWeatherSummary(metarStr);
    final rwyHeading = runway?.heading.toDouble();

    Color catBg = colors.successBg;
    Color catColor = colors.success;
    if (cat == 'MVFR') {
      catBg = colors.mvfrBg;
      catColor = colors.mvfr;
    } else if (cat == 'IFR') {
      catBg = colors.ifrBg;
      catColor = colors.ifr;
    } else if (cat == 'LIFR') {
      catBg = colors.lifrBg;
      catColor = colors.lifr;
    }

    return InkWell(
      onTap: metarStr.isNotEmpty ? onToggleRaw : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 20),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.divider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: colors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: WindArrow(
                      runwayHeading: rwyHeading,
                      windDir: parsed.windDirDeg,
                      windSpeedKt: parsed.windSpeedKt,
                      color: colors.accent,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: catBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    cat,
                    style: uiText(
                      context,
                      size: 10,
                      weight: FontWeight.w800,
                      color: catColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '${tempC?.round() ?? '--'}°C, $summary',
                  style: uiText(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
                const SizedBox(width: 20),
                Container(width: 1, height: 20, color: colors.dividerStrong),
                const SizedBox(width: 20),
                Expanded(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _WeatherStat(
                        label: 'WIND',
                        value:
                            '${parsed.windDirDeg?.round() ?? 'VRB'}° ${parsed.windSpeedKt?.round() ?? '--'}kt',
                      ),
                      _WeatherStat(
                        label: 'VIS',
                        value:
                            '${vis != null ? (vis >= 10 ? '10+' : vis.toStringAsFixed(1)) : '--'}km',
                      ),
                      _WeatherStat(
                        label: 'QNH',
                        value:
                            '${qnh?.value.round() ?? '--'}${qnh?.unit ?? ''}',
                      ),
                      _WeatherStat(
                        label: 'ELEV',
                        value: '${runway?.elevationFt?.round() ?? '--'}ft',
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.refresh, size: 16, color: colors.accent),
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
                style:
                    showRaw
                        ? uiText(
                          context,
                          size: 12,
                          weight: FontWeight.w500,
                          color: colors.textSecondary,
                        )
                        : uiText(
                          context,
                          size: 9,
                          weight: FontWeight.w700,
                          color: colors.textDim,
                          letterSpacing: 1,
                        ),
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
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.w700,
            color: colors.textDim,
          ),
        ),
        Text(
          value,
          style: uiText(
            context,
            size: 12,
            weight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
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
    final colors = context.colors;
    final f = feasibility;
    if (!isWeightFeasible) {
      return Text(
        'EXCEEDS MAX WEIGHT (${numFormat.format(maxWeightKg)} kg)',
        textAlign: TextAlign.right,
        style: uiText(
          context,
          size: 12,
          weight: FontWeight.w800,
          color: colors.error,
        ),
      );
    }
    if (isFuelOver) {
      return Text(
        'EXCEEDS FUEL CAPACITY (${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg)',
        textAlign: TextAlign.right,
        style: uiText(
          context,
          size: 12,
          weight: FontWeight.w800,
          color: colors.error,
        ),
      );
    }
    if (f == null) {
      return Text(
        '--',
        textAlign: TextAlign.right,
        style: uiText(context, size: 12, color: colors.textSecondary),
      );
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
            style: uiText(context, size: 12, color: colors.textSecondary),
            children: [
              const TextSpan(text: 'Runway required '),
              TextSpan(
                text: '$reqRunway m',
                style: uiText(
                  context,
                  size: 12,
                  weight: FontWeight.w800,
                  color: f.feasible ? colors.success : colors.error,
                ),
              ),
              TextSpan(text: ' vs $availRunway m avail'),
            ],
          ),
        ),
        if (noReheatFeasible) ...[
          const SizedBox(height: 4),
          Text(
            'Takeoff possible without reheat',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w700,
              color: colors.success,
            ),
          ),
        ],
      ],
    );
  }
}
