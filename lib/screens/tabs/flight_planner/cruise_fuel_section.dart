import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_flat_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../core/concorde_constants.dart';
import '../../../core/formatters.dart';
import '../../../models/concorde_models.dart';

/// CRUISE & FUEL MANAGEMENT card: distance/FL/fuel inputs, computed TOW,
/// fuel endurance, and the fuel breakdown panel.
class CruiseAndFuelSection extends ConsumerWidget {
  const CruiseAndFuelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final fuel = ref.watch(fuelBreakdownProvider);
    final mission = ref.watch(missionProfileProvider);
    final weights = ref.watch(weightsProvider);
    final extra = ref.watch(extraFuelProvider);
    final totalFuel = fuel.blockKg + extra;
    final isOverCapacity = totalFuel > ConcordeConstants.weights.fuelCapacityKg;
    final direction = ref.watch(flightDirectionProvider);

    // Calculate dynamic flight burn rate (kg/hour) and fuel endurance
    final double averageBurnRate = mission.totalTimeH > 0 && mission.tripKg > 0
        ? (mission.tripKg / mission.totalTimeH)
        : ConcordeConstants.fuel.cruiseFuelFlowKgHAtFl500;

    final double airborneFuel = math.max(0.0, totalFuel - fuel.taxiKg);
    final double fuelEnduranceH = averageBurnRate > 0
        ? (airborneFuel / averageBurnRate)
        : 0.0;

    final double reserveFuel =
        fuel.finalReserveKg + fuel.alternateKg + fuel.contingencyKg;
    final double reserveTimeH = averageBurnRate > 0
        ? (reserveFuel / averageBurnRate)
        : 0.0;
    final double etePlusReservesH = mission.totalTimeH + reserveTimeH;

    return EfbCard(
      title: 'CRUISE & FUEL MANAGEMENT',
      icon: Icons.local_gas_station_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: EfbTextField(
                              label: 'PLANNED DISTANCE (NM)',
                              initialValue: ref
                                  .watch(plannedDistanceProvider)
                                  .round()
                                  .toString(),
                              onChanged: (v) => ref
                                  .read(plannedDistanceProvider.notifier)
                                  .set(double.tryParse(v) ?? 0.0),
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
                                  initialValue: ref
                                      .watch(cruiseFLProvider)
                                      .round()
                                      .toString(),
                                  onChanged: (v) => ref
                                      .read(cruiseFLProvider.notifier)
                                      .set(
                                        double.tryParse(v) ?? 590.0,
                                        direction,
                                      ),
                                  keyboardType: TextInputType.number,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Direction (auto): ${direction == "E"
                                      ? "Eastbound"
                                      : direction == "W"
                                      ? "Westbound"
                                      : "unknown"}. snap to Non-RVSM.',
                                  style: uiText(
                                    context,
                                    color: colors.textDim,
                                    size: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: EfbTextField(
                              label: 'ALTERNATE ICAO (ALT)',
                              initialValue: ref.watch(alternateIcaoProvider),
                              onChanged: (v) => ref
                                  .read(alternateIcaoProvider.notifier)
                                  .set(v),
                              textCapitalization: TextCapitalization.characters,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: EfbTextField(
                              label: 'TAXI FUEL (KG)',
                              initialValue: ref
                                  .watch(taxiFuelProvider)
                                  .round()
                                  .toString(),
                              onChanged: (v) => ref
                                  .read(taxiFuelProvider.notifier)
                                  .set(double.tryParse(v) ?? 0.0),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: EfbTextField(
                              label: 'CONTINGENCY (%)',
                              initialValue: ref
                                  .watch(contingencyPctProvider)
                                  .round()
                                  .toString(),
                              onChanged: (v) => ref
                                  .read(contingencyPctProvider.notifier)
                                  .set(double.tryParse(v) ?? 0.0),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: EfbTextField(
                              label: 'FINAL RESERVE (KG)',
                              initialValue: ref
                                  .watch(finalReserveFuelProvider)
                                  .round()
                                  .toString(),
                              onChanged: (v) => ref
                                  .read(finalReserveFuelProvider.notifier)
                                  .set(double.tryParse(v) ?? 0.0),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: EfbTextField(
                              label: 'EXTRA FUEL (KG)',
                              initialValue: ref
                                  .watch(extraFuelProvider)
                                  .round()
                                  .toString(),
                              onChanged: (v) => ref
                                  .read(extraFuelProvider.notifier)
                                  .set(double.tryParse(v) ?? 0.0),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: colors.divider, thickness: 1),
                      const SizedBox(height: 16),
                      _StatGroup(
                        stats: [
                          _StatEntry(
                            label: 'COMPUTED TOW',
                            value:
                                '${numFormat.format(weights['TOW']!.round())} kg',
                          ),
                          _StatEntry(
                            label: 'FUEL ENDURANCE',
                            value: _formatHoursMinutes(fuelEnduranceH),
                          ),
                          _StatEntry(
                            label: 'ETE + RESERVES',
                            value: _formatHoursMinutes(etePlusReservesH),
                          ),
                          _StatEntry(
                            label: 'PASSENGERS',
                            value: '${ref.watch(paxCountProvider)} pax',
                            subtext:
                                '${numFormat.format(weights['PAX']!.round())} kg @ 84 kg each',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                VerticalDivider(color: colors.divider, thickness: 1, width: 1),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _FuelBreakdownPanel(
                    fuel: fuel,
                    extra: extra,
                    totalFuel: totalFuel,
                    isOverCapacity: isOverCapacity,
                    alternateDistanceNm: ref
                        .watch(alternateDistanceProvider)
                        .round(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reheat safety: climb reheat within ${ConcordeConstants.fuel.reheatMinutesCap} min cap.',
                style: uiText(
                  context,
                  color:
                      mission.climb.timeH * 60 <=
                          ConcordeConstants.fuel.reheatMinutesCap
                      ? colors.textDim
                      : colors.error,
                  size: 12,
                ),
              ),
              if (fuelEnduranceH < etePlusReservesH)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Fuel endurance is less than required ETE + reserves.',
                    style: uiText(context, color: colors.error, size: 12),
                  ),
                ),
              if (isOverCapacity)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Warning: this plan needs ${numFormat.format((totalFuel - ConcordeConstants.weights.fuelCapacityKg).round())} kg more fuel than '
                    'the aircraft can carry (capacity ${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg). '
                    'Reduce contingency/alternate/reserve, or plan a technical fuel stop.',
                    style: uiText(
                      context,
                      color: colors.error,
                      size: 12,
                      weight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

String _formatHoursMinutes(double hoursDecimal) {
  final h = hoursDecimal.floor();
  final m = ((hoursDecimal - h) * 60).round();
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}


class _StatEntry {
  final String label;
  final String value;
  final String? subtext;
  const _StatEntry({required this.label, required this.value, this.subtext});
}

/// COMPUTED TOW / FUEL ENDURANCE / ETE + RESERVES / PASSENGERS sharing one strip with shadow card styling
class _StatGroup extends StatelessWidget {
  final List<_StatEntry> stats;
  const _StatGroup({required this.stats});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      background: colors.inputBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: BorderRadius.circular(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: colors.dividerStrong,
              ),
            Expanded(child: _StatColumn(entry: stats[i])),
          ],
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final _StatEntry entry;
  const _StatColumn({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.label,
          style: uiText(
            context,
            size: 9,
            weight: FontWeight.bold,
            color: colors.textDim,
            letterSpacing: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          entry.value,
          style: uiText(
            context,
            size: 16,
            weight: FontWeight.w900,
            color: colors.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (entry.subtext != null) ...[
          const SizedBox(height: 4),
          Text(
            entry.subtext!,
            style: uiText(
              context,
              size: 10,
              color: colors.textDim,
              weight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// Authentic printed flight dispatch / ACARS thermal printer fuel strip.
/// Emulates the physical cockpit load sheet / fuel release strip with
/// serrated perforated edges, monospace dot-matrix alignment, and dispatch stamps.
class _FuelBreakdownPanel extends StatelessWidget {
  final BlockFuelBreakdown fuel;
  final double extra;
  final double totalFuel;
  final bool isOverCapacity;
  final int alternateDistanceNm;

  const _FuelBreakdownPanel({
    required this.fuel,
    required this.extra,
    required this.totalFuel,
    required this.isOverCapacity,
    required this.alternateDistanceNm,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Authentic thermal paper substrate
    final paperBg = isDark ? const Color(0xFF161619) : const Color(0xFFFAF9F5);
    final paperBorder = isDark ? const Color(0xFF2E2E34) : const Color(0xFFE2E0D8);
    final inkPrimary = isDark ? const Color(0xFFF4F4F5) : const Color(0xFF18181B);
    final inkSecondary = isDark ? const Color(0xFFA1A1AA) : const Color(0xFF52525B);
    final inkDim = isDark ? const Color(0xFF71717A) : const Color(0xFF8C8C94);

    return Container(
      decoration: BoxDecoration(
        color: paperBg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: paperBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Serrated / Perforated Torn Paper Edge
          CustomPaint(
            size: const Size(double.infinity, 6),
            painter: _PerforatedEdgePainter(
              color: paperBorder,
              fillColor: paperBg,
              isTop: true,
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header: ACARS / Dispatch Teletype Block
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CONCORDE 102 // FUEL REL',
                          style: uiText(
                            context,
                            size: 11,
                            weight: FontWeight.w900,
                            color: colors.accent,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'OFP MANIFEST • MSFS SIMCONNECT',
                          style: uiText(
                            context,
                            size: 8.5,
                            weight: FontWeight.w600,
                            color: inkDim,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: colors.accent.withValues(alpha: 0.5), width: 1),
                        borderRadius: BorderRadius.circular(3),
                        color: colors.accent.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        'DISPATCH',
                        style: uiText(
                          context,
                          size: 8,
                          weight: FontWeight.w900,
                          color: colors.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                _ThermalDivider(color: paperBorder, style: _ThermalDividerStyle.dashed),
                const SizedBox(height: 8),

                // Monospace Dot-Matrix Fuel Line Items
                _ThermalPrintRow(
                  label: 'TRIP FUEL',
                  value: fuel.tripKg,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),
                _ThermalPrintRow(
                  label: 'TAXI FUEL',
                  value: fuel.taxiKg,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),
                _ThermalPrintRow(
                  label: 'CONTINGENCY',
                  value: fuel.contingencyKg,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),
                _ThermalPrintRow(
                  label: 'EXTRA FUEL',
                  value: extra,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),
                _ThermalPrintRow(
                  label: 'ALT FUEL (${alternateDistanceNm}NM)',
                  value: fuel.alternateKg,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),
                _ThermalPrintRow(
                  label: 'FINAL RESERVE',
                  value: fuel.finalReserveKg,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),

                const SizedBox(height: 4),
                _ThermalDivider(color: paperBorder, style: _ThermalDividerStyle.dotted),
                const SizedBox(height: 6),

                _ThermalPrintRow(
                  label: 'BLOCK FUEL',
                  value: fuel.blockKg,
                  isBold: true,
                  inkPrimary: inkPrimary,
                  inkSecondary: inkSecondary,
                  inkDim: inkDim,
                ),

                const SizedBox(height: 8),
                // Double thermal print rule
                _ThermalDivider(color: paperBorder, style: _ThermalDividerStyle.doubleLine),
                const SizedBox(height: 12),

                // Total Required readout stamped block
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E22) : const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isOverCapacity
                          ? colors.error
                          : (isDark ? const Color(0xFF38383F) : const Color(0xFFD6D3C8)),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                'TOTAL REQUIRED',
                                style: uiText(
                                  context,
                                  size: 11,
                                  weight: FontWeight.w900,
                                  color: inkPrimary,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              if (isOverCapacity) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: colors.error,
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    'EXCEEDS TANK CAP',
                                    style: uiText(
                                      context,
                                      size: 7.5,
                                      weight: FontWeight.w900,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'BLOCK + EXTRA (${numFormat.format(extra.round())} KG)',
                            style: uiText(
                              context,
                              size: 8.5,
                              weight: FontWeight.w600,
                              color: inkDim,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            numFormat.format(totalFuel.round()),
                            style: uiText(
                              context,
                              size: 24,
                              weight: FontWeight.w900,
                              color: isOverCapacity
                                  ? colors.error
                                  : (isDark ? colors.accent : const Color(0xFFB45309)),
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'KG',
                            style: uiText(
                              context,
                              size: 11,
                              weight: FontWeight.bold,
                              color: inkDim,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),
                // Footer dispatch verification stamp
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '*** END OF LOAD SHEET ***',
                      style: uiText(
                        context,
                        size: 8,
                        weight: FontWeight.w700,
                        color: inkDim,
                        letterSpacing: 1.0,
                      ),
                    ),
                    Text(
                      'CAP: 95,681 KG',
                      style: uiText(
                        context,
                        size: 8,
                        weight: FontWeight.w800,
                        color: inkDim,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Bottom Serrated / Perforated Torn Paper Edge
          CustomPaint(
            size: const Size(double.infinity, 6),
            painter: _PerforatedEdgePainter(
              color: paperBorder,
              fillColor: paperBg,
              isTop: false,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThermalPrintRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  final Color inkPrimary;
  final Color inkSecondary;
  final Color inkDim;

  const _ThermalPrintRow({
    required this.label,
    required this.value,
    this.isBold = false,
    required this.inkPrimary,
    required this.inkSecondary,
    required this.inkDim,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          Text(
            label,
            style: uiText(
              context,
              size: isBold ? 11.5 : 11,
              weight: isBold ? FontWeight.w900 : FontWeight.w600,
              color: isBold ? inkPrimary : inkSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: CustomPaint(
              size: const Size(double.infinity, 8),
              painter: _DotLeaderPainter(color: inkDim.withValues(alpha: 0.45)),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            numFormat.format(value.round()),
            style: uiText(
              context,
              size: isBold ? 14 : 12.5,
              weight: isBold ? FontWeight.w900 : FontWeight.w700,
              color: inkPrimary,
              letterSpacing: 0.6,
            ),
          ),
        ],
      ),
    );
  }
}

enum _ThermalDividerStyle { dashed, dotted, doubleLine }

class _ThermalDivider extends StatelessWidget {
  final Color color;
  final _ThermalDividerStyle style;

  const _ThermalDivider({
    required this.color,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    if (style == _ThermalDividerStyle.doubleLine) {
      return Column(
        children: [
          Divider(color: color, thickness: 1, height: 1),
          const SizedBox(height: 2),
          Divider(color: color, thickness: 1, height: 1),
        ],
      );
    }

    return CustomPaint(
      size: const Size(double.infinity, 1),
      painter: _LinePatternPainter(
        color: color,
        isDotted: style == _ThermalDividerStyle.dotted,
      ),
    );
  }
}

class _LinePatternPainter extends CustomPainter {
  final Color color;
  final bool isDotted;

  _LinePatternPainter({required this.color, required this.isDotted});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final dashWidth = isDotted ? 2.0 : 5.0;
    final dashSpace = isDotted ? 3.0 : 4.0;
    double startX = 0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _LinePatternPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isDotted != isDotted;
}

class _DotLeaderPainter extends CustomPainter {
  final Color color;

  _DotLeaderPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    const spacing = 5.0;
    final centerY = size.height / 2;
    double currentX = 2;

    while (currentX < size.width - 2) {
      canvas.drawCircle(Offset(currentX, centerY), 0.75, paint);
      currentX += spacing;
    }
  }

  @override
  bool shouldRepaint(covariant _DotLeaderPainter oldDelegate) => oldDelegate.color != color;
}

/// Paints realistic jagged serrated teeth on top and bottom torn thermal paper edges.
class _PerforatedEdgePainter extends CustomPainter {
  final Color color;
  final Color fillColor;
  final bool isTop;

  _PerforatedEdgePainter({
    required this.color,
    required this.fillColor,
    required this.isTop,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const toothWidth = 6.0;
    final toothHeight = size.height;
    final teethCount = (size.width / toothWidth).ceil();

    final path = Path();
    final borderPath = Path();

    if (isTop) {
      path.moveTo(0, toothHeight);
      borderPath.moveTo(0, toothHeight);

      for (int i = 0; i < teethCount; i++) {
        final startX = i * toothWidth;
        final midX = startX + toothWidth / 2;
        final endX = startX + toothWidth;

        path.lineTo(midX, 0);
        path.lineTo(endX, toothHeight);

        borderPath.lineTo(midX, 0);
        borderPath.lineTo(endX, toothHeight);
      }

      path.lineTo(size.width, toothHeight);
      path.close();
    } else {
      path.moveTo(0, 0);
      borderPath.moveTo(0, 0);

      for (int i = 0; i < teethCount; i++) {
        final startX = i * toothWidth;
        final midX = startX + toothWidth / 2;
        final endX = startX + toothWidth;

        path.lineTo(midX, toothHeight);
        path.lineTo(endX, 0);

        borderPath.lineTo(midX, toothHeight);
        borderPath.lineTo(endX, 0);
      }

      path.lineTo(size.width, 0);
      path.close();
    }

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _PerforatedEdgePainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.isTop != isTop;
}

