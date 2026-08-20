import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/concorde_fuel_schematic.dart';
import '../../features/flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../../features/flight_monitor/data/models/telemetry_model.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fm_theme.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fm_toolbar.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/hero_pfd_row.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fuel_schematic_card.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/support_cards.dart';
import '../../features/flight_monitor/presentation/widgets/flight_monitor/fm_logbook.dart';
import '../../widgets/entrance_fader.dart';
import '../widgets/app_footer.dart';

/// Flight Monitor tab: SimConnect connection status, recording controls,
/// the live/playback avionics dashboard, and the flight recorder logbook.
///
/// Rebuilt from the "Flight Monitor Tab" Claude Design import — see
/// lib/features/flight_monitor/presentation/widgets/flight_monitor/ for the
/// individual cards.
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
    final notifier = ref.read(flightMonitorProvider.notifier);

    final telemetry = monitorState.currentTelemetry ?? TelemetryModel.empty();
    final isLiveOrPlayback = monitorState.currentTelemetry != null;
    // Always compute chips (even when disconnected, off empty/zeroed
    // telemetry) so tank labels stay visible — the whole section is already
    // dimmed via Opacity below when not live, so an empty list here would
    // just hide the tank IDs entirely rather than showing 0%.
    final chips = ConcordeFuelSchematic.computeTankFills(telemetry);
    final totalFuelKg = ConcordeFuelSchematic.totalFuelKg(chips);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (monitorState.isPlaybackMode)
          _PlaybackHeader(ref: ref, monitorState: monitorState)
        else
          FmToolbar(
            isConnected: monitorState.isConnected,
            isRecording: monitorState.isRecording,
            recordedFramesCount: monitorState.recordedFramesCount,
            telemetry: telemetry,
            onToggleRecording: () async {
              if (monitorState.isRecording) {
                await notifier.stopRecording();
              } else {
                notifier.startRecording();
              }
            },
          ),
        const SizedBox(height: 28),

        if (monitorState.isPlaybackMode && monitorState.playbackFrames.isNotEmpty) ...[
          _PlaybackScrubber(ref: ref, monitorState: monitorState),
          const SizedBox(height: 16),
        ],

        AbsorbPointer(
          absorbing: !isLiveOrPlayback,
          child: Opacity(
            opacity: isLiveOrPlayback ? 1.0 : 0.45,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HeroPfdRow(t: telemetry, isConnected: isLiveOrPlayback),
                const SizedBox(height: 16),
                _SupportGrid(t: telemetry, chips: chips, totalFuelKg: totalFuelKg),
              ],
            ),
          ),
        ),

        const SizedBox(height: 48),
        const FmLogbook(),
      ],
    );
  }
}

class _PlaybackHeader extends StatelessWidget {
  final WidgetRef ref;
  final FlightMonitorState monitorState;
  const _PlaybackHeader({required this.ref, required this.monitorState});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 9, height: 9, decoration: const BoxDecoration(color: fmAmber, shape: BoxShape.circle)),
            const SizedBox(width: 12),
            Text('LOG PLAYBACK MODE', style: fmLabel(size: 12, color: fmAmber, weight: FontWeight.w800, letterSpacing: 1.4)),
          ],
        ),
        TextButton.icon(
          icon: const Icon(Icons.exit_to_app, size: 16, color: fmTextFaint),
          label: Text('EXIT PLAYBACK', style: fmLabel(size: 12, color: fmTextFaint, letterSpacing: 0.4)),
          style: TextButton.styleFrom(backgroundColor: fmCard),
          onPressed: () => ref.read(flightMonitorProvider.notifier).exitPlayback(),
        ),
      ],
    );
  }
}

class _PlaybackScrubber extends StatelessWidget {
  final WidgetRef ref;
  final FlightMonitorState monitorState;
  const _PlaybackScrubber({required this.ref, required this.monitorState});

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(flightMonitorProvider.notifier);
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 14, color: fmTextFaint),
          onPressed: monitorState.playbackIndex > 0 ? () => notifier.setPlaybackIndex(monitorState.playbackIndex - 1) : null,
        ),
        Expanded(
          child: SliderTheme(
            data: SliderTheme.of(context).copyWith(activeTrackColor: fmAccent, thumbColor: fmAccent, inactiveTrackColor: fmBorder),
            child: Slider(
              min: 0.0,
              max: (monitorState.playbackFrames.length - 1).toDouble(),
              value: monitorState.playbackIndex.toDouble(),
              onChanged: (val) => notifier.setPlaybackIndex(val.toInt()),
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.arrow_forward_ios, size: 14, color: fmTextFaint),
          onPressed: monitorState.playbackIndex < monitorState.playbackFrames.length - 1
              ? () => notifier.setPlaybackIndex(monitorState.playbackIndex + 1)
              : null,
        ),
        const SizedBox(width: 8),
        Text('Frame: ${monitorState.playbackIndex + 1} / ${monitorState.playbackFrames.length}', style: fmMono(size: 11, color: fmMuted)),
      ],
    );
  }
}

class _SupportGrid extends StatelessWidget {
  final TelemetryModel t;
  final List<FuelTankChip> chips;
  final double totalFuelKg;
  const _SupportGrid({required this.t, required this.chips, required this.totalFuelKg});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 3, child: FuelSchematicCard(chips: chips, totalKg: totalFuelKg)),
              const SizedBox(width: 16),
              Expanded(child: CgCard(t: t)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: EnvironmentalCard(t: t)),
              const SizedBox(width: 16),
              Expanded(child: FuelBurnCard(t: t, totalFuelKg: totalFuelKg)),
              const SizedBox(width: 16),
              Expanded(child: TouchdownCard(t: t)),
              const SizedBox(width: 16),
              Expanded(child: GForceCard(t: t)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: EnginesReheatCard(t: t)),
              const SizedBox(width: 16),
              Expanded(child: GearFlapsDroopCard(t: t)),
            ],
          ),
        ),
      ],
    );
  }
}
