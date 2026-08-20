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
              Expanded(child: _TimeBox(label: 'TOTAL FLIGHT TIME', hoursDecimal: mission.totalTimeH)),
              const SizedBox(width: 16),
              Expanded(child: _TimeBox(label: 'CLIMB', hoursDecimal: mission.climb.timeH)),
              const SizedBox(width: 16),
              Expanded(child: _TimeBox(label: 'CRUISE', hoursDecimal: mission.cruise.timeH)),
              const SizedBox(width: 16),
              Expanded(child: _TimeBox(label: 'DESCENT', hoursDecimal: mission.descent.timeH)),
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
                                'Direction (auto): ${direction == "E" ? "Eastbound" : direction == "W" ? "Westbound" : "unknown"}. snap to Non-RVSM.',
                                style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 10),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: EfbTextField(
                            label: 'ALTERNATE ICAO (ALT)',
                            initialValue: ref.watch(alternateIcaoProvider),
                            onChanged: (v) => ref.read(alternateIcaoProvider.notifier).set(v),
                            textCapitalization: TextCapitalization.characters,
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
                        Expanded(child: EfbTextField(label: 'EXTRA TRIM TANK FUEL (KG)', initialValue: ref.watch(trimTankFuelProvider).round().toString(), onChanged: (v) => ref.read(trimTankFuelProvider.notifier).set(double.tryParse(v) ?? 0.0), keyboardType: TextInputType.number)),
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
                        Expanded(child: _BottomStatBox(label: 'COMPUTED TOW', value: '${numFormat.format(weights['TOW']!.round())} kg', isLarge: true)),
                        const SizedBox(width: 12),
                        Expanded(child: _BottomStatBox(label: 'FUEL ENDURANCE', value: _formatHoursMinutes(fuelEnduranceH))),
                        const SizedBox(width: 12),
                        Expanded(child: _BottomStatBox(label: 'ETE + RESERVES', value: _formatHoursMinutes(etePlusReservesH))),
                        const SizedBox(width: 12),
                        Expanded(child: _BottomStatBox(label: 'PASSENGERS', value: '${ref.watch(paxCountProvider)} pax', subtext: '${numFormat.format(weights['PAX']!.round())} kg @ 84 kg each')),
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
                        _FuelRow(label: 'Alt Fuel (${ref.watch(alternateDistanceProvider).round()} NM)', value: fuel.alternateKg),
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
                    'Warning: this plan needs ${numFormat.format((totalFuel - ConcordeConstants.weights.fuelCapacityKg).round())} kg more fuel than '
                    'the aircraft can carry (capacity ${numFormat.format(ConcordeConstants.weights.fuelCapacityKg)} kg). '
                    'Reduce contingency/alternate/reserve, or plan a technical fuel stop.',
                    style: GoogleFonts.plusJakartaSans(color: UiTokens.error, fontSize: 12, fontWeight: FontWeight.bold),
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

class _TimeBox extends StatelessWidget {
  final String label;
  final double hoursDecimal;
  const _TimeBox({required this.label, required this.hoursDecimal});

  @override
  Widget build(BuildContext context) {
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
}

class _BottomStatBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isLarge;
  final String? subtext;
  const _BottomStatBox({required this.label, required this.value, this.isLarge = false, this.subtext});

  @override
  Widget build(BuildContext context) {
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
                subtext!,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, color: UiTokens.textDim, fontWeight: FontWeight.w500),
              ),
            ],
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
  const _FuelRow({required this.label, required this.value, this.isBold = false});

  @override
  Widget build(BuildContext context) {
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
}

class _FuelDivider extends StatelessWidget {
  const _FuelDivider();
  @override
  Widget build(BuildContext context) => const Divider(color: Colors.white10, height: 16);
}
