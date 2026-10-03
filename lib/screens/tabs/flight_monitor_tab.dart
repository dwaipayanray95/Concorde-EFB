import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/concorde_fuel_schematic.dart';
import '../../features/flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../../features/flight_monitor/data/models/telemetry_model.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fm_toolbar.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/pfd_panel.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/cockpit_panels.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/mfd_strip.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/wifi_link_card.dart';
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
        const SizedBox(height: 16),
        // Wi-Fi link: share from the sim PC / connect from a phone or tablet.
        const WifiLinkCard(),
        const SizedBox(height: 16),

        AbsorbPointer(
          absorbing: !isLive,
          child: Opacity(
            opacity: isLive ? 1.0 : 0.45,
            child: _CockpitLayout(
              t: telemetry,
              isLive: isLive,
              chips: chips,
              totalFuelKg: totalFuelKg,
              fuelFlowKgH: monitorState.smoothedFuelFlowKgH,
              touchdown: monitorState.lastTouchdown,
            ),
          ),
        ),
      ],
    );
  }
}

/// Glass-cockpit page:
///   MFD strip (phase / nav / fuel prediction / annunciators)
///   route progress bar
///   PFD (attitude + speed/alt)      | engines
///   fuel schematic                  | CG + trim, fuel burn
///   environment | last touchdown
/// Narrow screens stack everything in the same order.
class _CockpitLayout extends StatelessWidget {
  final TelemetryModel t;
  final bool isLive;
  final List<FuelTankChip> chips;
  final double totalFuelKg;
  final double? fuelFlowKgH;
  final TouchdownRecord? touchdown;

  const _CockpitLayout({
    required this.t,
    required this.isLive,
    required this.chips,
    required this.totalFuelKg,
    required this.fuelFlowKgH,
    required this.touchdown,
  });

  @override
  Widget build(BuildContext context) {
    const gap = SizedBox(height: 16, width: 16);
    final mfd = MfdStrip(
      t: t,
      totalFuelKg: totalFuelKg,
      fuelFlowKgH: fuelFlowKgH,
      isLive: isLive,
    );
    final pfd = PfdPanel(t: t);
    final engines = EnginesPanel(t: t, fuelFlowKgH: fuelFlowKgH);
    final fuel = FuelSchematicCard(chips: chips, totalKg: totalFuelKg);
    final cg = CgTrimCard(t: t);
    final burn = FuelBurnCard(
      t: t,
      totalFuelKg: totalFuelKg,
      fuelFlowKgH: fuelFlowKgH,
    );
    final env = EnvironmentalCard(t: t);
    final td = TouchdownCard(touchdown: touchdown);

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 900) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, w) in [
                mfd,
                const FlightProgressBar(),
                pfd,
                engines,
                cg,
                fuel,
                burn,
                env,
                td,
              ].indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                w,
              ],
            ],
          );
        }
        Widget row(List<(int, Widget)> cells) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, c) in cells.indexed) ...[
                if (i > 0) gap,
                Expanded(flex: c.$1, child: c.$2),
              ],
            ],
          ),
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            mfd,
            const SizedBox(height: 12),
            const FlightProgressBar(),
            gap,
            row([(3, pfd), (2, engines)]),
            gap,
            row([
              (3, fuel),
              (
                2,
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [cg, gap, burn],
                ),
              ),
            ]),
            gap,
            row([(1, env), (1, td)]),
          ],
        );
      },
    );
  }
}
