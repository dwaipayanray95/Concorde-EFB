import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_flat_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../core/concorde_constants.dart';
import '../../../core/concorde_logic.dart';
import '../../../models/concorde_models.dart';
import '../../../core/formatters.dart';
import '../../../services/flight_plan_import_service.dart';

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
    final totalFuel = weights.plannedFuel;
    final isOverCapacity = weights.overCapacity;
    final direction = ref.watch(flightDirectionProvider);
    final endurance = ref.watch(fuelEnduranceProvider);
    final altStatus = ref.watch(alternateStatusProvider);
    final altIcao = ref.watch(alternateIcaoProvider);
    final altNm = ref.watch(alternateDistanceProvider);
    // Reheat is lit for the takeoff (~1.5 min) and the transonic
    // acceleration up to ~M1.7 (roughly 2/3 of the accel phase).
    final reheatMin = 1.5 + mission.accel.timeH * 60 * 2 / 3;

    return EfbCard(
      title: 'CRUISE & FUEL MANAGEMENT',
      icon: Icons.local_gas_station_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final inputs = Column(
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
                                  .set(double.tryParse(v) ?? 590.0, direction),
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
                          onChanged: (v) =>
                              ref.read(alternateIcaoProvider.notifier).set(v),
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
                        value: '${numFormat.format(weights.tow.round())} kg',
                        subtext:
                            'LW ${numFormat.format(weights.lw.round())} · ZFW ${numFormat.format(weights.zfw.round())}',
                      ),
                      // One meaningful number: how much longer the fuel
                      // lasts than the flight + reserves need.
                      _StatEntry(
                        label: 'ENDURANCE MARGIN',
                        value: _formatMargin(
                          endurance.enduranceH - endurance.requiredH,
                        ),
                        valueColor: endurance.sufficient ? null : colors.error,
                        subtext:
                            '${_formatHoursMinutes(endurance.enduranceH)} available · '
                            '${_formatHoursMinutes(endurance.requiredH)} needed',
                      ),
                      _StatEntry(
                        label: 'PASSENGERS',
                        value: '${ref.watch(paxCountProvider)} pax',
                        subtext:
                            '${numFormat.format(weights.pax.round())} kg @ 84 kg each',
                      ),
                    ],
                  ),
                ],
              );
              final strip = _FuelBreakdownPanel(
                fuel: fuel,
                extra: extra,
                totalFuel: totalFuel,
                isOverCapacity: isOverCapacity,
                alternateDistanceNm: ref
                    .watch(alternateDistanceProvider)
                    .round(),
                title: _stripTitle(
                  ref.watch(callSignProvider),
                  ref.watch(departureIcaoProvider),
                  ref.watch(arrivalIcaoProvider),
                ),
                subtitle:
                    '${_sourceLabel(ref.watch(flightPlanSourceProvider))} • '
                    'FL${mission.targetCruiseFl} • '
                    '${numFormat.format(ref.watch(plannedDistanceProvider).round())} NM • '
                    'ETE ${_formatHoursMinutes(mission.totalTimeH)}',
                // Over tank capacity is its own state -- the plan asks for
                // MORE fuel than fits, which is not "short".
                fuelStatus: isOverCapacity
                    ? 'OVER CAPACITY'
                    : (endurance.sufficient ? 'FUEL OK' : 'FUEL SHORT'),
                fuelOk: !isOverCapacity && endurance.sufficient,
              );
              // Phones / narrow windows: the fuel release strip goes under
              // the inputs instead of being squeezed beside them.
              if (constraints.maxWidth < 900) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [inputs, const SizedBox(height: 20), strip],
                );
              }
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: inputs),
                    const SizedBox(width: 24),
                    VerticalDivider(
                      color: colors.divider,
                      thickness: 1,
                      width: 1,
                    ),
                    const SizedBox(width: 24),
                    Expanded(flex: 2, child: strip),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reheat safety: ~${reheatMin.round()} min planned reheat (takeoff + transonic), '
                '${ConcordeConstants.fuel.reheatMinutesCap} min cap.',
                style: uiText(
                  context,
                  color: reheatMin <= ConcordeConstants.fuel.reheatMinutesCap
                      ? colors.textDim
                      : colors.error,
                  size: 12,
                ),
              ),
              if (mission.flCappedForDistance)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    mission.selectedCruiseFl >= ConcordeLogic.supersonicMinFl &&
                            !mission.supersonic
                        ? 'Sector too short for supersonic cruise -- planned subsonic (M0.95) at FL${mission.targetCruiseFl}.'
                        : 'Sector too short to reach FL${mission.selectedCruiseFl} -- planned at FL${mission.targetCruiseFl}.',
                    style: uiText(context, color: colors.accent, size: 12),
                  ),
                ),
              if (_alternateWarning(altStatus, altIcao, altNm) case final msg?)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    msg,
                    style: uiText(context, color: colors.accent, size: 12),
                  ),
                ),
              if (!endurance.sufficient)
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

String? _alternateWarning(AlternateStatus status, String icao, double nm) {
  return switch (status) {
    AlternateStatus.ok => null,
    AlternateStatus.missing =>
      'No alternate selected -- alternate fuel is 0 kg. Add an alternate for a legal dispatch.',
    AlternateStatus.sameAsArrival =>
      'Alternate is the same as the arrival airport -- choose a different alternate.',
    AlternateStatus.unknownAirport =>
      'Alternate $icao not found in the airport database -- alternate fuel is 0 kg.',
    AlternateStatus.tooFar =>
      'Alternate $icao is ${nm.round()} nm from the arrival -- beyond a sensible diversion range '
          '(${ConcordeConstants.fuel.maxSensibleAlternateNm.round()} nm). Alternate fuel is very high.',
  };
}

/// "BAW1 // EGLL-KJFK" once a call sign is loaded, else just the route.
String _stripTitle(String callSign, String dep, String arr) {
  final route = '${dep.isEmpty ? '----' : dep}-${arr.isEmpty ? '----' : arr}';
  final cs = callSign.trim();
  return cs.isEmpty || cs == '--' ? '$route // FUEL RELEASE' : '$cs // $route';
}

String _sourceLabel(FlightPlanSource source) => switch (source) {
  FlightPlanSource.simbrief => 'SIMBRIEF OFP',
  FlightPlanSource.file => 'IMPORTED PLAN',
  FlightPlanSource.manual => 'MANUAL ROUTE',
  FlightPlanSource.none => 'EFB PLAN',
};

/// "+12 MIN", "-1h 05m", "+0 MIN".
String _formatMargin(double hours) {
  final mins = (hours * 60).round();
  final sign = mins < 0 ? '-' : '+';
  final a = mins.abs();
  return a < 60
      ? '$sign$a MIN'
      : '$sign${a ~/ 60}h ${(a % 60).toString().padLeft(2, '0')}m';
}

String _formatHoursMinutes(double hoursDecimal) {
  final total = (hoursDecimal * 60).round();
  final h = total ~/ 60;
  final m = total % 60;
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

class _StatEntry {
  final String label;
  final String value;
  final String? subtext;
  final Color? valueColor;
  const _StatEntry({
    required this.label,
    required this.value,
    this.subtext,
    this.valueColor,
  });
}

/// COMPUTED TOW / ENDURANCE MARGIN / PASSENGERS sharing one strip with shadow card styling
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
            color: entry.valueColor ?? colors.textPrimary,
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
            maxLines: 2,
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
  final String title;
  final String subtitle;
  final bool fuelOk;
  final String fuelStatus;

  const _FuelBreakdownPanel({
    required this.title,
    required this.subtitle,
    required this.fuelOk,
    required this.fuelStatus,
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
    final badgeColor = fuelOk ? colors.success : colors.error;

    // Authentic thermal paper substrate
    final paperBg = isDark ? const Color(0xFF161619) : const Color(0xFFFAF9F5);
    final paperBorder = isDark
        ? const Color(0xFF2E2E34)
        : const Color(0xFFE2E0D8);
    final inkPrimary = isDark
        ? const Color(0xFFF4F4F5)
        : const Color(0xFF18181B);
    final inkSecondary = isDark
        ? const Color(0xFFA1A1AA)
        : const Color(0xFF52525B);
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                            subtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
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
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: badgeColor.withValues(alpha: 0.5),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(3),
                        color: badgeColor.withValues(alpha: 0.08),
                      ),
                      child: Text(
                        fuelStatus,
                        style: uiText(
                          context,
                          size: 8,
                          weight: FontWeight.w900,
                          color: badgeColor,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),
                _ThermalDivider(
                  color: paperBorder,
                  style: _ThermalDividerStyle.dashed,
                ),
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
                _ThermalDivider(
                  color: paperBorder,
                  style: _ThermalDividerStyle.dotted,
                ),
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
                _ThermalDivider(
                  color: paperBorder,
                  style: _ThermalDividerStyle.doubleLine,
                ),
                const SizedBox(height: 12),

                // Total Required readout stamped block
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E22)
                        : const Color(0xFFF1EFE8),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isOverCapacity
                          ? colors.error
                          : (isDark
                                ? const Color(0xFF38383F)
                                : const Color(0xFFD6D3C8)),
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
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
                                  : (isDark
                                        ? colors.accent
                                        : const Color(0xFFB45309)),
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

  const _ThermalDivider({required this.color, required this.style});

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
  bool shouldRepaint(covariant _DotLeaderPainter oldDelegate) =>
      oldDelegate.color != color;
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
