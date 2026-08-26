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
                      _PhaseTimeGroup(
                        phases: [
                          MapEntry('TOTAL FLIGHT TIME', mission.totalTimeH),
                          MapEntry('CLIMB', mission.climb.timeH),
                          MapEntry('CRUISE', mission.cruise.timeH),
                          MapEntry('DESCENT', mission.descent.timeH),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Divider(color: colors.divider, thickness: 1),
                      const SizedBox(height: 16),
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

/// TOTAL FLIGHT TIME / CLIMB / CRUISE / DESCENT sharing one strip with shadow card styling
class _PhaseTimeGroup extends StatelessWidget {
  final List<MapEntry<String, double>> phases;
  const _PhaseTimeGroup({required this.phases});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      background: colors.inputBg,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                color: colors.dividerStrong,
              ),
            Expanded(
              child: _PhaseTimeColumn(
                label: phases[i].key,
                hoursDecimal: phases[i].value,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseTimeColumn extends StatelessWidget {
  final String label;
  final double hoursDecimal;
  const _PhaseTimeColumn({required this.label, required this.hoursDecimal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: uiText(
              context,
              color: colors.textPrimary,
              weight: FontWeight.w900,
            ),
            children: [
              TextSpan(text: '$h', style: const TextStyle(fontSize: 20)),
              TextSpan(
                text: ' h  ',
                style: uiText(
                  context,
                  size: 11,
                  color: colors.textDim,
                  weight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: m.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 20),
              ),
              TextSpan(
                text: ' m',
                style: uiText(
                  context,
                  size: 11,
                  color: colors.textDim,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.bold,
            color: colors.textDim,
            letterSpacing: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
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
      borderRadius: BorderRadius.circular(16),
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

/// The fuel breakdown/"Total Required" panel matching _LegCard's strip pattern with shadow card styling
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
    return EfbFlatCard(
      background: colors.inputBg,
      borderRadius: BorderRadius.circular(16),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FuelRow(label: 'Trip Fuel', value: fuel.tripKg),
          const _FuelDivider(),
          _FuelRow(label: 'Taxi Fuel', value: fuel.taxiKg),
          const _FuelDivider(),
          _FuelRow(label: 'Contingency', value: fuel.contingencyKg),
          const _FuelDivider(),
          _FuelRow(label: 'Extra Fuel', value: extra),
          const _FuelDivider(),
          _FuelRow(
            label: 'Alt Fuel ($alternateDistanceNm NM)',
            value: fuel.alternateKg,
          ),
          const _FuelDivider(),
          _FuelRow(label: 'Final Reserve', value: fuel.finalReserveKg),
          const _FuelDivider(),
          _FuelRow(label: 'Block Fuel', value: fuel.blockKg, isBold: true),
          const SizedBox(height: 24),
          Divider(color: colors.dividerStrong, thickness: 1),
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
                    style: uiText(
                      context,
                      size: 14,
                      weight: FontWeight.bold,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Block + Extra (${numFormat.format(extra)} kg)',
                    style: uiText(context, size: 10, color: colors.textDim),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    numFormat.format(totalFuel),
                    style: uiText(
                      context,
                      size: 28,
                      weight: FontWeight.w900,
                      color: isOverCapacity ? colors.error : colors.success,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'kg',
                    style: uiText(context, size: 14, color: colors.textDim),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FuelRow extends StatelessWidget {
  final String label;
  final double value;
  final bool isBold;
  const _FuelRow({
    required this.label,
    required this.value,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: uiText(
              context,
              size: 14,
              weight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? colors.textPrimary : colors.textSecondary,
            ),
          ),
          Text(
            numFormat.format(value.round()),
            style: uiText(
              context,
              size: isBold ? 18 : 16,
              weight: FontWeight.bold,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FuelDivider extends StatelessWidget {
  const _FuelDivider();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Divider(color: colors.divider, height: 16);
  }
}
