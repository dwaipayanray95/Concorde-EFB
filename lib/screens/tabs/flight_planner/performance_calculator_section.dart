import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/wind_arrow.dart';
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
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;

        final departureLeg = _LegCard(
          legLabel: 'DEPARTURE / TAKEOFF',
          legIcon: Icons.flight_takeoff,
          accent: colors.departure,
          icao: ref.watch(departureIcaoProvider),
          onIcaoChanged: (v) => ref.read(departureIcaoProvider.notifier).set(v),
          airport: ref.watch(depAirportProvider),
          currentRunwayId: ref.watch(departureRunwayIdProvider),
          onRunwayChanged: (v) =>
              ref.read(departureRunwayIdProvider.notifier).set(v ?? ''),
          runway: ref.watch(departureRunwayProvider),
          metarAsync: ref.watch(departureMetarFutureProvider),
          onRefreshMetar: () => ref.invalidate(departureMetarFutureProvider),
          weightKg: ref.watch(weightsProvider).tow,
          weightLabel: 'TOW',
          speeds: {
            'V1': ref.watch(takeoffSpeedsProvider).v1,
            'VR': ref.watch(takeoffSpeedsProvider).vr,
            'V2': ref.watch(takeoffSpeedsProvider).v2,
          },
          conditionMode: ref.watch(departureRunwayConditionProvider),
          onConditionChanged: (m) =>
              ref.read(departureRunwayConditionProvider.notifier).set(m),
          speedColor: colors.accent,
          feasibility: ref.watch(takeoffFeasibilityProvider),
          maxWeightKg: ConcordeConstants.weights.mtowKg,
          noReheatFeasibility: ref.watch(takeoffFeasibilityNoReheatProvider),
        );

        final arrivalLeg = _LegCard(
          legLabel: 'ARRIVAL / LANDING',
          legIcon: Icons.flight_land,
          accent: colors.arrival,
          icao: ref.watch(arrivalIcaoProvider),
          onIcaoChanged: (v) => ref.read(arrivalIcaoProvider.notifier).set(v),
          airport: ref.watch(arrAirportProvider),
          currentRunwayId: ref.watch(arrivalRunwayIdProvider),
          onRunwayChanged: (v) =>
              ref.read(arrivalRunwayIdProvider.notifier).set(v ?? ''),
          runway: ref.watch(arrivalRunwayProvider),
          metarAsync: ref.watch(arrivalMetarFutureProvider),
          onRefreshMetar: () => ref.invalidate(arrivalMetarFutureProvider),
          weightKg: ref.watch(weightsProvider).lw,
          weightLabel: 'LW',
          speeds: {
            'VREF': ref.watch(landingSpeedsProvider).vref,
            'VAPP': ref.watch(landingSpeedsProvider).vapp,
          },
          conditionMode: ref.watch(arrivalRunwayConditionProvider),
          onConditionChanged: (m) =>
              ref.read(arrivalRunwayConditionProvider.notifier).set(m),
          speedColor: colors.arrival,
          feasibility: ref.watch(landingFeasibilityProvider),
          maxWeightKg: ConcordeConstants.weights.mlwKg,
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [departureLeg, const SizedBox(height: 16), arrivalLeg],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: departureLeg),
              const SizedBox(width: 16),
              Expanded(child: arrivalLeg),
            ],
          ),
        );
      },
    );
  }
}

class _LegCard extends ConsumerWidget {
  final String legLabel;
  final IconData legIcon;
  final Color accent;
  final String icao;
  final ValueChanged<String> onIcaoChanged;
  final Airport? airport;
  final String currentRunwayId;
  final ValueChanged<String?> onRunwayChanged;
  final Runway? runway;
  final AsyncValue<String> metarAsync;
  final VoidCallback onRefreshMetar;
  final double weightKg;
  final String weightLabel;
  final Map<String, double> speeds;
  final Color speedColor;
  final RunwayFeasibility? feasibility;
  final double maxWeightKg;
  final RunwayFeasibility? noReheatFeasibility;
  final RunwayConditionMode conditionMode;
  final ValueChanged<RunwayConditionMode> onConditionChanged;

  const _LegCard({
    required this.legLabel,
    required this.legIcon,
    required this.accent,
    required this.icao,
    required this.onIcaoChanged,
    required this.airport,
    required this.currentRunwayId,
    required this.onRunwayChanged,
    required this.runway,
    required this.metarAsync,
    required this.onRefreshMetar,
    required this.weightKg,
    required this.weightLabel,
    required this.speeds,
    required this.speedColor,
    required this.feasibility,
    required this.maxWeightKg,
    this.noReheatFeasibility,
    required this.conditionMode,
    required this.onConditionChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isFuelOver = ref.watch(weightsProvider).overCapacity;
    final isWeightFeasible = weightKg <= maxWeightKg;
    final isFeasible = (feasibility?.feasible ?? true) && isWeightFeasible;
    final metarStr = metarAsync.asData?.value ?? '';
    final parsedWind = MetarParser.parseWind(metarStr);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.dividerStrong.withValues(alpha: isDark ? 0.6 : 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identity row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141417) : const Color(0xFFEBEBEF),
              border: Border(
                bottom: BorderSide(
                  color: isFeasible
                      ? colors.dividerStrong.withValues(
                          alpha: isDark ? 0.5 : 0.7,
                        )
                      : colors.error.withValues(alpha: 0.5),
                  width: isFeasible ? 1.0 : 1.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3.5,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isFeasible ? colors.accent : colors.error,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Icon(
                  legIcon,
                  size: 14,
                  color: isFeasible ? colors.accent : colors.error,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    legLabel,
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w800,
                      color: colors.textPrimary,
                      letterSpacing: 1.4,
                    ),
                  ),
                ),
                // Authentic Cockpit Annunciator Box
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isFeasible
                        ? colors.success.withValues(alpha: 0.15)
                        : colors.error,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isFeasible
                          ? colors.success.withValues(alpha: 0.6)
                          : colors.error,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isFeasible) ...[
                        const Icon(
                          Icons.warning_amber_rounded,
                          size: 13,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 5),
                      ],
                      Text(
                        isFeasible ? 'WITHIN LIMITS' : 'PERF LIMIT EXCEEDED',
                        style: uiText(
                          context,
                          size: 10,
                          weight: FontWeight.w900,
                          color: isFeasible ? colors.success : Colors.white,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Everything below flows in one vertical stack: ICAO/runway +
          // wind, METAR, then the big weight/speeds/margin block.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _IcaoField(value: icao, onChanged: onIcaoChanged),
                            const SizedBox(height: 16),
                            _RunwaySelect(
                              airport: airport,
                              currentId: currentRunwayId,
                              onChanged: onRunwayChanged,
                              hasDeficit:
                                  (feasibility != null &&
                                  feasibility!.runwayLengthM <
                                      feasibility!.requiredLengthMEst),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Container(width: 1, color: colors.divider),
                      const SizedBox(width: 20),
                      // Matches the combined height of the stacked ICAO +
                      // RUNWAY fields above (label + field, twice, plus
                      // the gap between them) -- IntrinsicHeight can't
                      // be queried via LayoutBuilder, so this is
                      // measured by hand rather than derived at layout
                      // time.
                      Expanded(
                        flex: 2,
                        child: SizedBox(
                          height: 148,
                          child: Center(
                            child: WindArrow(
                              runwayHeading: runway?.heading.toDouble(),
                              windDir: parsedWind.windDirDeg,
                              windSpeedKt: parsedWind.windSpeedKt,
                              windGustKt: parsedWind.windGustKt,
                              color: colors.accent,
                              size: 148,
                              runwayLabel: runway?.id,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                _WeatherStrip(
                  metarStr: metarAsync.value ?? '',
                  runway: runway,
                  isLoading: metarAsync.isLoading,
                  isError: metarAsync.hasError,
                  errorMessage: metarAsync.error?.toString(),
                  onRefresh: onRefreshMetar,
                ),
                const SizedBox(height: 14),
                _RunwayConditionSelector(
                  mode: conditionMode,
                  resolved: feasibility?.condition,
                  onChanged: onConditionChanged,
                ),
                if (feasibility != null && !feasibility!.windDataAvailable) ...[
                  const SizedBox(height: 10),
                  Text(
                    'NO WIND DATA -- crosswind/tailwind limits not checked. '
                    'Verify the wind before dispatch.',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w700,
                      color: colors.accent,
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Divider(color: colors.divider, height: 1),
                const SizedBox(height: 20),
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
                const SizedBox(height: 14),
                Row(
                  children: speeds.entries.map((e) {
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: _SpeedChip(
                          label: e.key,
                          value: e.value.round().toString(),
                          color: speedColor,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                _RunwayMarginText(
                  feasibility: feasibility,
                  isWeightFeasible: isWeightFeasible,
                  isFuelOver: isFuelOver,
                  maxWeightKg: maxWeightKg,
                  noReheatFeasible: noReheatFeasibility?.feasible ?? false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// One boxed V-speed/reference-speed value under the big TOW/LW figure.
class _SpeedChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SpeedChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.dividerStrong.withValues(alpha: 0.6),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'KT',
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: uiText(
              context,
              size: 20,
              weight: FontWeight.w900,
              color: color,
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
            border: Border.all(color: colors.dividerStrong, width: 1.5),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: TextEditingController(text: value)
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
  final bool hasDeficit;

  const _RunwaySelect({
    required this.airport,
    required this.currentId,
    required this.onChanged,
    this.hasDeficit = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
            if (hasDeficit)
              Text(
                'LENGTH DEFICIT',
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w900,
                  color: colors.error,
                  letterSpacing: 0.6,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: colors.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: hasDeficit ? colors.error : colors.dividerStrong,
              width: hasDeficit ? 1.8 : 1.5,
            ),
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
  final bool isLoading;
  final bool isError;
  final String? errorMessage;
  final VoidCallback onRefresh;

  const _WeatherStrip({
    required this.metarStr,
    required this.runway,
    this.isLoading = false,
    this.isError = false,
    this.errorMessage,
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
    final ageMin = MetarParser.metarAgeMinutes(metarStr);
    final gust = parsed.windGustKt;

    // Solid category color as the whole strip's background (not just the
    // badge), so text needs to switch to white-on-color rather than the
    // usual dim/primary tones meant for a neutral background.
    Color catBg = colors.success;
    if (isError && metarStr.isEmpty) {
      catBg = colors.error.withValues(alpha: 0.85);
    } else if (cat == 'MVFR') {
      catBg = colors.mvfr;
    } else if (cat == 'IFR') {
      catBg = colors.ifr;
    } else if (cat == 'LIFR') {
      catBg = colors.lifr;
    } else if (metarStr.isEmpty) {
      catBg = colors.dividerStrong;
    }
    const catColor = Colors.white;
    final dimOnCat = Colors.white.withValues(alpha: 0.75);

    final headline = isError && metarStr.isEmpty
        ? 'OFFLINE'
        : (metarStr.isEmpty && isLoading ? 'FETCHING' : cat);
    final conditions = isError && metarStr.isEmpty
        ? 'Unable to fetch METAR'
        : (metarStr.isNotEmpty
              ? summary
              : (isLoading ? 'Updating weather...' : '--'));
    final windText = parsed.windSpeedKt == null
        ? '--'
        : '${parsed.windDirDeg?.round().toString().padLeft(3, '0') ?? 'VRB'}°/'
              '${parsed.windSpeedKt!.round()}${gust != null ? 'G${gust.round()}' : ''}KT';
    final stale = ageMin != null && ageMin > 90;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
          decoration: BoxDecoration(
            color: catBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Row 1: flight category + plain-language conditions.
              Row(
                children: [
                  Text(
                    headline,
                    style: uiText(
                      context,
                      size: 14,
                      weight: FontWeight.w900,
                      color: catColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(width: 1, height: 16, color: dimOnCat),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      conditions,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiText(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: catColor,
                      ),
                    ),
                  ),
                  _AnimatedRefreshButton(
                    isLoading: isLoading,
                    color: catColor,
                    onPressed: onRefresh,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(height: 1, color: dimOnCat.withValues(alpha: 0.35)),
              const SizedBox(height: 10),
              // Row 2: equal-width readouts so the strip never wraps
              // into ragged rows.
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Row(
                  children: [
                    _WeatherCell(
                      flex: 3,
                      label: 'WIND',
                      value: windText,
                      labelColor: dimOnCat,
                      valueColor: catColor,
                    ),
                    _WeatherCell(
                      label: 'VIS',
                      value: vis != null
                          ? (vis >= 10
                                ? '10+ KM'
                                : '${vis.toStringAsFixed(1)} KM')
                          : '--',
                      labelColor: dimOnCat,
                      valueColor: catColor,
                    ),
                    _WeatherCell(
                      label: 'TEMP',
                      value: tempC != null ? '${tempC.round()}°C' : '--',
                      labelColor: dimOnCat,
                      valueColor: catColor,
                    ),
                    _WeatherCell(
                      label: 'QNH',
                      value: qnh == null
                          ? '--'
                          : (qnh.unit == 'hPa'
                                ? '${qnh.value.round()}'
                                : qnh.value.toStringAsFixed(2)),
                      labelColor: dimOnCat,
                      valueColor: catColor,
                    ),
                    _WeatherCell(
                      label: 'ELEV',
                      value: '${runway?.elevationFt?.round() ?? '--'} FT',
                      labelColor: dimOnCat,
                      valueColor: catColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (metarStr.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SelectableText(
                  metarStr,
                  style: uiText(
                    context,
                    size: 11,
                    weight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ),
              if (ageMin != null) ...[
                const SizedBox(width: 12),
                Text(
                  'OBSERVED ${formatMetarAge(ageMin)} AGO${stale ? ' · OUTDATED' : ''}',
                  style: uiText(
                    context,
                    size: 9,
                    weight: FontWeight.w800,
                    color: stale ? colors.error : colors.textDim,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ],
          ),
        ] else if (isError) ...[
          const SizedBox(height: 8),
          Text(
            'Failed to retrieve weather. Tap refresh to retry.',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w600,
              color: colors.error,
            ),
          ),
        ],
      ],
    );
  }
}

/// "36 MINS", "1 HR 5 MINS" -- spelled out, never "36m".
String formatMetarAge(int minutes) {
  final m = minutes < 0 ? 0 : minutes;
  String mins(int v) => '$v ${v == 1 ? 'MIN' : 'MINS'}';
  if (m < 60) return mins(m);
  final h = m ~/ 60;
  final hrs = '$h ${h == 1 ? 'HR' : 'HRS'}';
  return m % 60 == 0 ? hrs : '$hrs ${mins(m % 60)}';
}

/// One equal-width readout in the METAR strip: small label above value.
class _WeatherCell extends StatelessWidget {
  final String label;
  final String value;
  final Color labelColor;
  final Color valueColor;
  final int flex;
  const _WeatherCell({
    this.flex = 2,
    required this.label,
    required this.value,
    required this.labelColor,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    // Gusty winds ("310°/15G24KT") get a wider cell, and every cell keeps
    // a right gap so values never run into the next one.
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: uiText(
                context,
                size: 9,
                weight: FontWeight.w800,
                color: labelColor,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: uiText(
                  context,
                  size: 13,
                  weight: FontWeight.w800,
                  color: valueColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedRefreshButton extends StatefulWidget {
  final bool isLoading;
  final Color color;
  final VoidCallback onPressed;

  const _AnimatedRefreshButton({
    required this.isLoading,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_AnimatedRefreshButton> createState() => _AnimatedRefreshButtonState();
}

class _AnimatedRefreshButtonState extends State<_AnimatedRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isLoading) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(_AnimatedRefreshButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isLoading != oldWidget.isLoading) {
      if (widget.isLoading) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.reset();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: widget.isLoading
          ? 'Fetching ATIS/METAR...'
          : 'Refresh ATIS/METAR',
      icon: RotationTransition(
        turns: _controller,
        child: Icon(Icons.refresh, size: 18, color: widget.color),
      ),
      padding: const EdgeInsets.all(4),
      constraints: const BoxConstraints(),
      onPressed: widget.isLoading ? null : widget.onPressed,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final f = feasibility;

    // Collect all exceedances / decision barriers
    final violations = <String>[];
    if (!isWeightFeasible) {
      violations.add(
        'AIRCRAFT EXCEEDS MAX WEIGHT (${numFormat.format(maxWeightKg)} kg)',
      );
    }
    if (isFuelOver) {
      violations.add(
        'EXCEEDS FUEL CAPACITY (${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg)',
      );
    }
    if (f != null) {
      if (f.runwayLengthM < f.requiredLengthMEst) {
        final deficit = (f.requiredLengthMEst - f.runwayLengthM).round();
        violations.add(
          'RUNWAY LENGTH DEFICIT (-$deficit m shortfall for dispatch)',
        );
      }
      if (!f.altitudeOk) {
        violations.add(
          'AIRFIELD OUTSIDE ALTITUDE LIMITS (${ConcordeConstants.runway.minAirfieldAltFt.round()} - ${ConcordeConstants.runway.maxAirfieldAltFt.round()} ft)',
        );
      }
      if (!f.crosswindOk) {
        violations.add(
          'EXCEEDS MAX CROSSWIND LIMIT (${ConcordeConstants.runway.maxCrosswindKt.round()} kt)',
        );
      }
      if (!f.tailwindOk) {
        violations.add(
          'EXCEEDS MAX TAILWIND LIMIT (${ConcordeConstants.runway.maxTailwindKt.round()} kt)',
        );
      }
    }

    final hasViolations = violations.isNotEmpty;

    if (f == null && !hasViolations) {
      return Text(
        '--',
        style: uiText(context, size: 12, color: colors.textSecondary),
      );
    }

    final reqRunway = f != null
        ? numFormat.format(f.requiredLengthMEst.round())
        : '--';
    final availRunway = f != null
        ? numFormat.format(f.runwayLengthM.round())
        : '--';
    final marginM = f != null
        ? (f.runwayLengthM - f.requiredLengthMEst).round()
        : 0;
    final marginText = marginM >= 0
        ? '+$marginM m margin'
        : '$marginM m deficit';

    if (hasViolations) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.error.withValues(alpha: isDark ? 0.12 : 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: colors.error.withValues(alpha: isDark ? 0.7 : 0.9),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.block, size: 15, color: colors.error),
                const SizedBox(width: 8),
                Text(
                  'DISPATCH DECISION: PERFORMANCE NO-GO',
                  style: uiText(
                    context,
                    size: 11,
                    weight: FontWeight.w900,
                    color: colors.error,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Specific exceedance lines
            ...violations.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: uiText(
                        context,
                        size: 11,
                        weight: FontWeight.w900,
                        color: colors.error,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        v,
                        style: uiText(
                          context,
                          size: 11,
                          weight: FontWeight.w700,
                          color: isDark
                              ? const Color(0xFFFCA5A5)
                              : colors.error,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Container(height: 1, color: colors.error.withValues(alpha: 0.25)),
            const SizedBox(height: 6),
            RichText(
              text: TextSpan(
                style: uiText(context, size: 11, color: colors.textSecondary),
                children: [
                  const TextSpan(text: 'Calculated: '),
                  TextSpan(
                    text: '$reqRunway m required',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w800,
                      color: colors.error,
                    ),
                  ),
                  TextSpan(text: ' vs $availRunway m available ($marginText)'),
                ],
              ),
            ),
            if (f != null && !f.widthOk) ...[
              const SizedBox(height: 4),
              Text(
                'CAUTION: NARROW RUNWAY (min ${ConcordeConstants.runway.minRunwayWidthFt.round()} ft)',
                style: uiText(
                  context,
                  size: 11,
                  weight: FontWeight.w800,
                  color: colors.mvfr,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // FEASIBLE (WITHIN LIMITS) presentation
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
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
                  color: colors.success,
                ),
              ),
              TextSpan(text: ' vs $availRunway m avail ($marginText)'),
            ],
          ),
        ),
        if (f != null && !f.widthOk) ...[
          const SizedBox(height: 4),
          Text(
            'CAUTION: NARROW RUNWAY (min ${ConcordeConstants.runway.minRunwayWidthFt.round()} ft)',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.mvfr,
            ),
          ),
        ],
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

/// AUTO / DRY / WET / CONTAM selector. AUTO derives the surface state from
/// the METAR present/recent weather and shows what it resolved to.
class _RunwayConditionSelector extends StatelessWidget {
  final RunwayConditionMode mode;
  final RunwayCondition? resolved;
  final ValueChanged<RunwayConditionMode> onChanged;

  const _RunwayConditionSelector({
    required this.mode,
    required this.resolved,
    required this.onChanged,
  });

  static String _label(RunwayConditionMode m) => switch (m) {
    RunwayConditionMode.auto => 'AUTO',
    RunwayConditionMode.dry => 'DRY',
    RunwayConditionMode.wet => 'WET',
    RunwayConditionMode.contaminated => 'CONTAM',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final resolvedText = resolved == null
        ? ''
        : ' · ${resolved!.name.toUpperCase()}';
    return Row(
      children: [
        Text(
          'RWY COND',
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.w800,
            color: colors.textDim,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: RunwayConditionMode.values.map((m) {
              final selected = m == mode;
              return InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => onChanged(m),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? colors.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: selected ? colors.accent : colors.dividerStrong,
                    ),
                  ),
                  child: Text(
                    m == RunwayConditionMode.auto && selected
                        ? '${_label(m)}$resolvedText'
                        : _label(m),
                    style: uiText(
                      context,
                      size: 10,
                      weight: FontWeight.w800,
                      color: selected
                          ? AppColors.dark.bg
                          : colors.textSecondary,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}
