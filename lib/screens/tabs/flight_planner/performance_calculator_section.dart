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
  bool showDepRaw = false;
  bool showArrRaw = false;

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
          onIcaoChanged: (v) =>
              ref.read(departureIcaoProvider.notifier).set(v),
          airport: ref.watch(depAirportProvider),
          currentRunwayId: ref.watch(departureRunwayIdProvider),
          onRunwayChanged: (v) =>
              ref.read(departureRunwayIdProvider.notifier).set(v ?? ''),
          runway: ref.watch(departureRunwayProvider),
          metarAsync: ref.watch(departureMetarFutureProvider),
          onRefreshMetar: () =>
              ref.invalidate(departureMetarFutureProvider),
          showRaw: showDepRaw,
          onToggleRaw: () => setState(() => showDepRaw = !showDepRaw),
          weightKg: ref.watch(weightsProvider)['TOW']!,
          weightLabel: 'TOW',
          speeds: ref.watch(takeoffSpeedsProvider),
          speedColor: colors.accent,
          feasibility: ref.watch(takeoffFeasibilityProvider),
          maxWeightKg: ConcordeConstants.weights.mtowKg,
          noReheatFeasibility: ref.watch(
            takeoffFeasibilityNoReheatProvider,
          ),
        );

        final arrivalLeg = _LegCard(
          legLabel: 'ARRIVAL / LANDING',
          legIcon: Icons.flight_land,
          accent: colors.arrival,
          icao: ref.watch(arrivalIcaoProvider),
          onIcaoChanged: (v) =>
              ref.read(arrivalIcaoProvider.notifier).set(v),
          airport: ref.watch(arrAirportProvider),
          currentRunwayId: ref.watch(arrivalRunwayIdProvider),
          onRunwayChanged: (v) =>
              ref.read(arrivalRunwayIdProvider.notifier).set(v ?? ''),
          runway: ref.watch(arrivalRunwayProvider),
          metarAsync: ref.watch(arrivalMetarFutureProvider),
          onRefreshMetar: () =>
              ref.invalidate(arrivalMetarFutureProvider),
          showRaw: showArrRaw,
          onToggleRaw: () => setState(() => showArrRaw = !showArrRaw),
          weightKg: ref.watch(weightsProvider)['LW']!,
          weightLabel: 'LW',
          speeds: ref.watch(landingSpeedsProvider),
          speedColor: colors.arrival,
          feasibility: ref.watch(landingFeasibilityProvider),
          maxWeightKg: ConcordeConstants.weights.mlwKg,
        );

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              departureLeg,
              const SizedBox(height: 16),
              arrivalLeg,
            ],
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
    final isFeasible = (feasibility?.feasible ?? true) && isWeightFeasible;
    final metarStr = metarAsync.asData?.value ?? '';
    final parsedWind = MetarParser.parseWind(metarStr);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBorderColor = isFeasible ? colors.dividerStrong.withValues(alpha: isDark ? 0.6 : 0.8) : colors.error;

    return Container(
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: statusBorderColor,
          width: isFeasible ? 1.0 : 1.5,
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141417) : const Color(0xFFEBEBEF),
              border: Border(
                bottom: BorderSide(
                  color: colors.dividerStrong.withValues(alpha: isDark ? 0.5 : 0.7),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: isFeasible ? colors.accent : colors.error,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                Icon(legIcon, size: 14, color: isFeasible ? colors.accent : colors.error),
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
                  showRaw: showRaw,
                  isLoading: metarAsync.isLoading,
                  isError: metarAsync.hasError,
                  errorMessage: metarAsync.error?.toString(),
                  onToggleRaw: onToggleRaw,
                  onRefresh: onRefreshMetar,
                ),
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
            border: Border.all(color: colors.dividerStrong, width: 1.5),
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
  final bool isLoading;
  final bool isError;
  final String? errorMessage;
  final VoidCallback onToggleRaw;
  final VoidCallback onRefresh;

  const _WeatherStrip({
    required this.metarStr,
    required this.runway,
    required this.showRaw,
    this.isLoading = false,
    this.isError = false,
    this.errorMessage,
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

    return InkWell(
      onTap: metarStr.isNotEmpty ? onToggleRaw : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: catBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isError && metarStr.isEmpty ? 'OFFLINE' : (metarStr.isEmpty && isLoading ? 'FETCHING' : cat),
                  style: uiText(
                    context,
                    size: 12,
                    weight: FontWeight.w800,
                    color: catColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  isError && metarStr.isEmpty
                      ? 'Unable to fetch METAR'
                      : (tempC != null ? '${tempC.round()}°C, $summary' : (isLoading ? 'Updating weather...' : '--')),
                  style: uiText(
                    context,
                    size: 12,
                    weight: FontWeight.w700,
                    color: catColor,
                  ),
                ),
                const SizedBox(width: 16),
                Container(width: 1, height: 20, color: dimOnCat),
                const SizedBox(width: 16),
                Expanded(
                  child: Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _WeatherStat(
                        label: 'WIND',
                        value:
                            '${parsed.windDirDeg?.round() ?? 'VRB'}° ${parsed.windSpeedKt?.round() ?? '--'}kt',
                        labelColor: dimOnCat,
                        valueColor: catColor,
                      ),
                      _WeatherStat(
                        label: 'VIS',
                        value:
                            '${vis != null ? (vis >= 10 ? '10+' : vis.toStringAsFixed(1)) : '--'}km',
                        labelColor: dimOnCat,
                        valueColor: catColor,
                      ),
                      _WeatherStat(
                        label: 'QNH',
                        value:
                            '${qnh?.value.round() ?? '--'}${qnh?.unit ?? ''}',
                        labelColor: dimOnCat,
                        valueColor: catColor,
                      ),
                      _WeatherStat(
                        label: 'ELEV',
                        value: '${runway?.elevationFt?.round() ?? '--'}ft',
                        labelColor: dimOnCat,
                        valueColor: catColor,
                      ),
                    ],
                  ),
                ),
                _AnimatedRefreshButton(
                  isLoading: isLoading,
                  color: catColor,
                  onPressed: onRefresh,
                ),
              ],
            ),
          ),
          if (metarStr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              showRaw ? metarStr : 'TAP TO SHOW RAW METAR',
              style: showRaw
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
      tooltip: widget.isLoading ? 'Fetching ATIS/METAR...' : 'Refresh ATIS/METAR',
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

class _WeatherStat extends StatelessWidget {
  final String label;
  final String value;
  final Color? labelColor;
  final Color? valueColor;
  const _WeatherStat({
    required this.label,
    required this.value,
    this.labelColor,
    this.valueColor,
  });

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
            color: labelColor ?? colors.textDim,
          ),
        ),
        Text(
          value,
          style: uiText(
            context,
            size: 12,
            weight: FontWeight.w700,
            color: valueColor ?? colors.textPrimary,
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
        style: uiText(context, size: 12, color: colors.textSecondary),
      );
    }
    final reqRunway = numFormat.format(f.requiredLengthMEst.round());
    final availRunway = numFormat.format(f.runwayLengthM.round());
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
                  color: f.feasible ? colors.success : colors.error,
                ),
              ),
              TextSpan(text: ' vs $availRunway m avail'),
            ],
          ),
        ),
        if (isFuelOver) ...[
          const SizedBox(height: 4),
          Text(
            'EXCEEDS FUEL CAPACITY (${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg)',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.error,
            ),
          ),
        ],
        if (!f.widthOk) ...[
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
        if (!f.altitudeOk) ...[
          const SizedBox(height: 4),
          Text(
            'AIRFIELD OUTSIDE ALTITUDE LIMITS (${ConcordeConstants.runway.minAirfieldAltFt.round()} to ${ConcordeConstants.runway.maxAirfieldAltFt.round()} ft)',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.error,
            ),
          ),
        ],
        if (!f.crosswindOk) ...[
          const SizedBox(height: 4),
          Text(
            'EXCEEDS MAX CROSSWIND (${ConcordeConstants.runway.maxCrosswindKt.round()} kt)',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.error,
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
