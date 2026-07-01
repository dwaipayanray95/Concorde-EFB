import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ui_tokens.dart';
import 'package:concorde_efb/widgets/efb_glass_container.dart';
import '../controllers/telemetry_provider.dart';
import '../../data/services/flight_recorder_service.dart';

class FlightHistoryDashboard extends ConsumerWidget {
  const FlightHistoryDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(flightHistoryFutureProvider);

    return historyAsync.when(
      data: (flights) {
        if (flights.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.history_toggle_off, size: 48, color: Colors.white24),
                  const SizedBox(height: 16),
                  Text(
                    'NO FLIGHT LOGS RECORDED YET',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Colors.white38,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Start recording telemetry in the dashboard during your flights!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: Colors.white24,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: flights.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final flight = flights[index];
            return _buildFlightCard(context, ref, flight);
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(40.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40.0),
          child: Text(
            'Error loading flight history.',
            style: GoogleFonts.plusJakartaSans(color: Colors.redAccent),
          ),
        ),
      ),
    );
  }

  Widget _buildFlightCard(BuildContext context, WidgetRef ref, FlightRecordHeader flight) {
    final durationStr = _formatDuration(flight.durationSeconds);
    final hasTouchdown = flight.touchdownVS != null;

    Color vsColor = Colors.greenAccent;
    if (hasTouchdown) {
      final absVs = flight.touchdownVS!.abs();
      if (absVs > 500) {
        vsColor = Colors.redAccent;
      } else if (absVs > 250) {
        vsColor = Colors.amberAccent;
      }
    }

    return EfbGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10, width: 1.0),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Flight Meta Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flight_takeoff, color: UiTokens.accent, size: 20),
            ),
            const SizedBox(width: 16),
            
            // Text Meta
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    flight.date,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Duration: $durationStr',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white30,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (hasTouchdown) ...[
                        Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Landing: ${flight.touchdownVS!.round()} FPM / ${flight.touchdownPitch!.toStringAsFixed(1)}° / ${flight.touchdownGForce!.toStringAsFixed(2)}G',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: vsColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Actions Block
            Row(
              children: [
                // Load Playback Button
                IconButton(
                  tooltip: 'Load timeline playback',
                  icon: const Icon(Icons.play_circle_fill, color: Colors.greenAccent, size: 24),
                  onPressed: () {
                    ref.read(flightMonitorProvider.notifier).startPlayback(flight.id);
                  },
                ),
                // Delete Button
                IconButton(
                  tooltip: 'Delete recording',
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    _showDeleteConfirmation(context, ref, flight);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref, FlightRecordHeader flight) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        title: Text(
          'DELETE FLIGHT LOG?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        content: Text(
          'Are you sure you want to permanently delete the flight recording from ${flight.date}?',
          style: GoogleFonts.plusJakartaSans(color: Colors.white54, fontSize: 12),
        ),
        actions: [
          TextButton(
            child: Text('CANCEL', style: GoogleFonts.plusJakartaSans(color: Colors.white30)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text('DELETE', style: GoogleFonts.plusJakartaSans(color: Colors.redAccent)),
            onPressed: () {
              ref.read(flightMonitorProvider.notifier).deleteRecordedFlight(flight.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}s';
    final m = seconds ~/ 60;
    if (m < 60) {
      final s = seconds % 60;
      return '${m}m ${s}s';
    }
    final h = m ~/ 60;
    final rm = m % 60;
    final rs = seconds % 60;
    return '${h}h ${rm}m ${rs}s';
  }
}
