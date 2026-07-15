import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../features/flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../../features/flight_monitor/data/models/telemetry_model.dart';
import '../../features/flight_monitor/presentation/widgets/concorde_lcd_panel.dart';
import '../../features/flight_monitor/presentation/widgets/flight_history_dashboard.dart';
import '../../widgets/entrance_fader.dart';
import '../widgets/app_footer.dart';

/// Flight Monitor tab: SimConnect connection status, recording controls,
/// the live/playback LCD avionics panel, and the flight recorder logbook.
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
          child: _buildFlightMonitorSection(ref),
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

  Widget _buildFlightMonitorSection(WidgetRef ref) {
    final monitorState = ref.watch(flightMonitorProvider);
    final notifier = ref.read(flightMonitorProvider.notifier);

    Widget controlsHeader;
    if (monitorState.isPlaybackMode) {
      controlsHeader = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.amberAccent, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(
                'LOG PLAYBACK MODE',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amberAccent),
              ),
            ],
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.exit_to_app, size: 16),
            label: const Text('EXIT PLAYBACK'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.white10),
            onPressed: () {
              notifier.exitPlayback();
            },
          ),
        ],
      );
    } else {
      controlsHeader = Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: monitorState.isConnected ? Colors.greenAccent : Colors.redAccent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                monitorState.isConnected ? 'SIMCONNECT BRIDGE CONNECTED' : 'DISCONNECTED FROM SIMCONNECT BRIDGE',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: monitorState.isConnected ? Colors.greenAccent : Colors.white30,
                ),
              ),
            ],
          ),
          if (monitorState.isConnected)
            ElevatedButton.icon(
              icon: Icon(monitorState.isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.red),
              label: Text(monitorState.isRecording ? 'STOP RECORDING (${monitorState.recordedFramesCount})' : 'START RECORDING'),
              style: ElevatedButton.styleFrom(
                backgroundColor: monitorState.isRecording ? Colors.red.withValues(alpha: 0.2) : Colors.white10,
              ),
              onPressed: () async {
                if (monitorState.isRecording) {
                  await notifier.stopRecording();
                } else {
                  notifier.startRecording();
                }
              },
            ),
        ],
      );
    }

    final telemetry = monitorState.currentTelemetry ?? TelemetryModel.empty();
    final isLiveOrPlayback = monitorState.currentTelemetry != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        controlsHeader,
        const SizedBox(height: 24),
        if (monitorState.isPlaybackMode && monitorState.playbackFrames.isNotEmpty) ...[
          // Timeline Scrubbing Slider
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios, size: 14),
                onPressed: monitorState.playbackIndex > 0
                    ? () => notifier.setPlaybackIndex(monitorState.playbackIndex - 1)
                    : null,
              ),
              Expanded(
                child: Slider(
                  min: 0.0,
                  max: (monitorState.playbackFrames.length - 1).toDouble(),
                  value: monitorState.playbackIndex.toDouble(),
                  onChanged: (val) {
                    notifier.setPlaybackIndex(val.toInt());
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 14),
                onPressed: monitorState.playbackIndex < monitorState.playbackFrames.length - 1
                    ? () => notifier.setPlaybackIndex(monitorState.playbackIndex + 1)
                    : null,
              ),
              const SizedBox(width: 8),
              Text(
                'Frame: ${monitorState.playbackIndex + 1} / ${monitorState.playbackFrames.length}',
                style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Always show the Concorde Glass LCD Avionics Cockpit panel
        AbsorbPointer(
          absorbing: !isLiveOrPlayback,
          child: Opacity(
            opacity: isLiveOrPlayback ? 1.0 : 0.45,
            child: ConcordeLcdPanel(
              telemetry: telemetry,
              isConnected: isLiveOrPlayback,
            ),
          ),
        ),

        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FLIGHT RECORDER LOGBOOK',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const FlightHistoryDashboard(),
      ],
    );
  }
}
