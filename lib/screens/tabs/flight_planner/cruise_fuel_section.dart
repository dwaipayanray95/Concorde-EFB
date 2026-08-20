import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../widgets/efb_glass_container.dart';
import '../../../core/ui_tokens.dart';
import '../../../core/concorde_constants.dart';
import '../../../core/formatters.dart';
import '../../../models/concorde_models.dart';

/// CRUISE & FUEL MANAGEMENT card: distance/FL/fuel inputs, computed TOW,
/// fuel endurance, and the fuel breakdown panel.
class CruiseAndFuelSection extends ConsumerWidget {
  const CruiseAndFuelSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                      const Divider(color: Colors.white10, thickness: 1),
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
                                  style: GoogleFonts.plusJakartaSans(
                                    color: UiTokens.textDim,
                                    fontSize: 10,
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
                              label: 'EXTRA TRIM (KG)',
                              initialValue: ref
                                  .watch(trimTankFuelProvider)
                                  .round()
                                  .toString(),
                              onChanged: (v) => ref
                                  .read(trimTankFuelProvider.notifier)
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
                      const Divider(color: Colors.white10, thickness: 1),
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
                const VerticalDivider(
                  color: Colors.white10,
                  thickness: 1,
                  width: 1,
                ),
                const SizedBox(width: 24),
                Expanded(
                  flex: 2,
                  child: _FuelBreakdownPanel(
                    fuel: fuel,
                    trim: trim,
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
                style: GoogleFonts.plusJakartaSans(
                  color:
                      mission.climb.timeH * 60 <=
                          ConcordeConstants.fuel.reheatMinutesCap
                      ? UiTokens.textDim
                      : UiTokens.error,
                  fontSize: 12,
                ),
              ),
              if (fuelEnduranceH < etePlusReservesH)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Fuel endurance is less than required ETE + reserves.',
                    style: GoogleFonts.plusJakartaSans(
                      color: UiTokens.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              if (isOverCapacity)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Warning: this plan needs ${numFormat.format((totalFuel - ConcordeConstants.weights.fuelCapacityKg).round())} kg more fuel than '
                    'the aircraft can carry (capacity ${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg). '
                    'Reduce contingency/alternate/reserve, or plan a technical fuel stop.',
                    style: GoogleFonts.plusJakartaSans(
                      color: UiTokens.error,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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

/// TOTAL FLIGHT TIME / CLIMB / CRUISE / DESCENT sharing one border, each phase's time stacked
/// above its label rather than three separate boxes.
class _PhaseTimeGroup extends StatelessWidget {
  final List<MapEntry<String, double>> phases;
  const _PhaseTimeGroup({required this.phases});

  @override
  Widget build(BuildContext context) {
    return EfbGlassContainer(
      blur: 10,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            for (var i = 0; i < phases.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white10,
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
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: GoogleFonts.jetBrainsMono(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
            children: [
              TextSpan(text: '$h', style: const TextStyle(fontSize: 20)),
              TextSpan(
                text: ' h  ',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: UiTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: m.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 20),
              ),
              TextSpan(
                text: ' m',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: UiTokens.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: UiTokens.textDim,
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

/// COMPUTED TOW / FUEL ENDURANCE / ETE + RESERVES / PASSENGERS sharing one
/// border, matching [_PhaseTimeGroup]'s treatment.
class _StatGroup extends StatelessWidget {
  final List<_StatEntry> stats;
  const _StatGroup({required this.stats});

  @override
  Widget build(BuildContext context) {
    return EfbGlassContainer(
      blur: 10,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < stats.length; i++) ...[
              if (i > 0)
                Container(
                  width: 1,
                  height: 34,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  color: Colors.white10,
                ),
              Expanded(child: _StatColumn(entry: stats[i])),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final _StatEntry entry;
  const _StatColumn({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          entry.label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: UiTokens.textDim,
            letterSpacing: 1,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        Text(
          entry.value,
          style: GoogleFonts.jetBrainsMono(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (entry.subtext != null) ...[
          const SizedBox(height: 4),
          Text(
            entry.subtext!,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: UiTokens.textDim,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}

/// The fuel breakdown/"Total Required" panel, pulled out so it can sit
/// beside the phase-time group instead of below the input fields.
class _FuelBreakdownPanel extends StatelessWidget {
  final BlockFuelBreakdown fuel;
  final double trim;
  final double extra;
  final double totalFuel;
  final bool isOverCapacity;
  final int alternateDistanceNm;

  const _FuelBreakdownPanel({
    required this.fuel,
    required this.trim,
    required this.extra,
    required this.totalFuel,
    required this.isOverCapacity,
    required this.alternateDistanceNm,
  });

  @override
  Widget build(BuildContext context) {
    return EfbGlassContainer(
      blur: 15,
      borderRadius: BorderRadius.circular(16),
      child: Container(
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
            _FuelRow(label: 'Extra Trim Fuel', value: trim),
            const _FuelDivider(),
            _FuelRow(label: 'Extra Fuel', value: extra),
            const _FuelDivider(),
            _FuelRow(
              label: 'Alt Fuel ($alternateDistanceNm NM)',
              value: fuel.alternateKg,
            ),
            const _FuelDivider(),
            _FuelRow(label: 'Block Fuel', value: fuel.blockKg, isBold: true),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: UiTokens.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Block + Trim + Extra (${numFormat.format(trim + extra)} kg)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        color: UiTokens.textSecondary.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      numFormat.format(totalFuel),
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: isOverCapacity
                            ? UiTokens.error
                            : UiTokens.success,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'kg',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 14,
                        color: UiTokens.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.white : UiTokens.textSecondary,
            ),
          ),
          Text(
            numFormat.format(value.round()),
            style: GoogleFonts.jetBrainsMono(
              fontSize: isBold ? 18 : 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
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
  Widget build(BuildContext context) =>
      const Divider(color: Colors.white10, height: 16);
}
