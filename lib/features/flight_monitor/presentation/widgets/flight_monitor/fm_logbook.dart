import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/formatters.dart';
import '../../controllers/telemetry_provider.dart';
import '../../../data/services/flight_recorder_service.dart';
import 'fm_theme.dart';

/// FLIGHT RECORDER LOGBOOK: compact table matching the new design, wired to
/// real saved recordings (with playback/delete actions preserved from the
/// previous card-based dashboard).
class FmLogbook extends ConsumerWidget {
  const FmLogbook({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(flightHistoryFutureProvider);

    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: historyAsync.when(
        data: (flights) => _buildTable(context, ref, flights),
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text('Error loading flight history.', style: fmLabel(color: fmRed)),
        ),
      ),
    );
  }

  Widget _buildTable(BuildContext context, WidgetRef ref, List<FlightRecordHeader> flights) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('FLIGHT RECORDER LOGBOOK', style: fmLabel()),
            Text('${flights.length} RECORDINGS', style: fmLabel(size: 11, weight: FontWeight.w700, letterSpacing: 0)),
          ],
        ),
        const SizedBox(height: 16),
        if (flights.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.history_toggle_off, size: 40, color: fmTextDim),
                  const SizedBox(height: 12),
                  Text('NO FLIGHT LOGS RECORDED YET', style: fmLabel(size: 11)),
                ],
              ),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: fmBorder))),
            child: Row(
              children: [
                Expanded(flex: 12, child: Text('DATE', style: fmLabel(size: 10, color: fmTextDim, letterSpacing: 0.8))),
                Expanded(flex: 10, child: Text('ROUTE', style: fmLabel(size: 10, color: fmTextDim, letterSpacing: 0.8))),
                Expanded(flex: 10, child: Text('DURATION', style: fmLabel(size: 10, color: fmTextDim, letterSpacing: 0.8))),
                Expanded(flex: 10, child: Text('MAX MACH', style: fmLabel(size: 10, color: fmTextDim, letterSpacing: 0.8))),
                Expanded(flex: 8, child: Text('MAX ALT', style: fmLabel(size: 10, color: fmTextDim, letterSpacing: 0.8))),
                const SizedBox(width: 72),
              ],
            ),
          ),
          for (final flight in flights) _LogRow(flight: flight, ref: ref),
        ],
      ],
    );
  }
}

class _LogRow extends StatelessWidget {
  final FlightRecordHeader flight;
  final WidgetRef ref;
  const _LogRow({required this.flight, required this.ref});

  @override
  Widget build(BuildContext context) {
    final hasTouchdown = flight.touchdownVS != null;
    Color vsColor = fmGreen;
    if (hasTouchdown) {
      final absVs = flight.touchdownVS!.abs();
      if (absVs > 500) {
        vsColor = fmRed;
      } else if (absVs > 250) {
        vsColor = fmAmber;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Color(0xFF141B29)))),
      child: Row(
        children: [
          Expanded(
            flex: 12,
            child: Text(
              flight.date,
              style: fmMono(size: 12, color: fmTextFaint, weight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              flight.route.isEmpty ? '--' : flight.route,
              style: fmMono(size: 12, color: fmTextFaint, weight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 10,
            child: Tooltip(
              message: hasTouchdown
                  ? 'Touchdown: ${flight.touchdownVS!.round()} FPM / ${flight.touchdownPitch!.toStringAsFixed(1)}° / ${flight.touchdownGForce!.toStringAsFixed(2)}G'
                  : 'No touchdown recorded',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasTouchdown) ...[
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: vsColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                  ],
                  Text(_formatDuration(flight.durationSeconds), style: fmMono(size: 12, color: fmTextFaint, weight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 10,
            child: Text(
              flight.maxMach != null ? 'M${flight.maxMach!.toStringAsFixed(2)}' : '--',
              style: fmMono(size: 12, color: fmAccent, weight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              flight.maxAltitudeFt != null ? numFormat.format(flight.maxAltitudeFt!.round()) : '--',
              style: fmMono(size: 12, color: fmTextFaint, weight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 72,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Load timeline playback',
                  icon: Icon(Icons.play_circle_fill, color: fmGreen.withValues(alpha: 0.85), size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => ref.read(flightMonitorProvider.notifier).startPlayback(flight.id),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete recording',
                  icon: Icon(Icons.delete_outline, color: fmRed.withValues(alpha: 0.85), size: 18),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: () => _confirmDelete(context, ref, flight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) return '${m}m ${seconds % 60}s';
    final h = m ~/ 60;
    return '${h}h ${m % 60}m';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, FlightRecordHeader flight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: fmCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: fmBorder)),
        title: Text('DELETE FLIGHT LOG?', style: fmLabel(size: 14, color: fmTextPrimary, letterSpacing: 0.5)),
        content: Text(
          'Are you sure you want to permanently delete the flight recording from ${flight.date}?',
          style: fmLabel(size: 12, color: fmTextSecondary, weight: FontWeight.w600, letterSpacing: 0),
        ),
        actions: [
          TextButton(
            child: Text('CANCEL', style: fmLabel(size: 12, color: fmMuted, letterSpacing: 0)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('DELETE', style: fmLabel(size: 12, color: fmRed, letterSpacing: 0)),
            onPressed: () {
              ref.read(flightMonitorProvider.notifier).deleteRecordedFlight(flight.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
