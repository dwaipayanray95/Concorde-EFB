import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/concorde_fuel_schematic.dart';
import '../../features/flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../../features/flight_monitor/data/models/telemetry_model.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fm_toolbar.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/hero_pfd_row.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/mfd_strip.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fuel_schematic_card.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/support_cards.dart';
import '../../widgets/entrance_fader.dart';
import '../widgets/app_footer.dart';

/// Flight Monitor tab: SimConnect connection status, the live avionics
/// dashboard, and the auto-logged flight logbook.
class FlightMonitorTab extends ConsumerWidget {
  const FlightMonitorTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        EntranceFader(
          key: const ValueKey('monitor-section'),
          delay: const Duration(milliseconds: 100),
          child: _FlightMonitorSection(ref: ref),
        ),
        const SizedBox(height: 64),
        EntranceFader(
          key: const ValueKey('monitor-footer'),
          delay: const Duration(milliseconds: 220),
          child: const AppFooter(),
        ),
      ],
    );
  }
}

class _FlightMonitorSection extends StatelessWidget {
  final WidgetRef ref;
  const _FlightMonitorSection({required this.ref});

  @override
  Widget build(BuildContext context) {
    final monitorState = ref.watch(flightMonitorProvider);

    final telemetry = monitorState.currentTelemetry ?? TelemetryModel.empty();
    final isLive = monitorState.currentTelemetry != null;
    final chips = ConcordeFuelSchematic.computeTankFills(telemetry);
    final totalFuelKg = ConcordeFuelSchematic.totalFuelKg(chips);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FmToolbar(
          isConnected: monitorState.isConnected,
          telemetry: telemetry,
          bridgeMessage: monitorState.bridge.socketConnected
              ? monitorState.bridge.message
              : null,
        ),
        const SizedBox(height: 28),

        AbsorbPointer(
          absorbing: !isLive,
          child: Opacity(
            opacity: isLive ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MfdStrip(
                  t: telemetry,
                  totalFuelKg: totalFuelKg,
                  fuelFlowKgH: monitorState.smoothedFuelFlowKgH,
                  isLive: isLive,
                ),
                const SizedBox(height: 16),
                HeroPfdRow(t: telemetry, isConnected: isLive),
                const SizedBox(height: 16),
                _SupportGrid(
                  t: telemetry,
                  chips: chips,
                  totalFuelKg: totalFuelKg,
                  fuelFlowKgH: monitorState.smoothedFuelFlowKgH,
                  touchdown: monitorState.lastTouchdown,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportGrid extends StatelessWidget {
  final TelemetryModel t;
  final List<FuelTankChip> chips;
  final double totalFuelKg;
  final double? fuelFlowKgH;
  final TouchdownRecord? touchdown;
  const _SupportGrid({
    required this.t,
    required this.chips,
    required this.totalFuelKg,
    this.fuelFlowKgH,
    this.touchdown,
  });

  @override
  Widget build(BuildContext context) {
    // Fuel schematic (the Concorde-specific centrepiece) beside the CG,
    // engines and fuel-burn cards; the smaller environmental / G / landing
    // cards share one row underneath. Narrow screens stack everything.
    final side = [
      CgCard(t: t),
      EnginesReheatCard(t: t),
      FuelBurnCard(t: t, totalFuelKg: totalFuelKg, fuelFlowKgH: fuelFlowKgH),
    ];
    final bottom = [
      EnvironmentalCard(t: t),
      GForceCard(t: t),
      TouchdownCard(touchdown: touchdown),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FuelSchematicCard(chips: chips, totalKg: totalFuelKg),
              for (final w in [...side, ...bottom]) ...[
                const SizedBox(height: 12),
                w,
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 3,
                    child: FuelSchematicCard(
                      chips: chips,
                      totalKg: totalFuelKg,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < side.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          side[i],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < bottom.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: bottom[i]),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
