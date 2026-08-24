import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../core/formatters.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../controllers/telemetry_provider.dart';
import '../../../data/models/flight_log_entry.dart';

/// FLIGHT LOGBOOK: one auto-logged row per completed flight (takeoff to
/// landing, detected from telemetry) -- no manual record button, no
/// timeline/playback, just a summary per trip.
class FmLogbook extends ConsumerWidget {
  const FmLogbook({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final historyAsync = ref.watch(flightLogHistoryFutureProvider);

    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: historyAsync.when(
        data: (flights) => _buildTable(context, ref, flights),
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, stack) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Error loading flight history.',
            style: uiText(context, color: colors.error),
          ),
        ),
      ),
    );
  }

  Widget _buildTable(
    BuildContext context,
    WidgetRef ref,
    List<FlightLogEntry> flights,
  ) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FLIGHT LOGBOOK',
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w800,
                color: colors.textDim,
                letterSpacing: 1.6,
              ),
            ),
            Text(
              '${flights.length} RECORDINGS',
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w700,
                color: colors.textDim,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (flights.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.history_toggle_off,
                    size: 40,
                    color: colors.textDim,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'NO FLIGHTS LOGGED YET -- FLY A TAKEOFF & LANDING',
                    style: uiText(context, size: 11, color: colors.textDim),
                  ),
                ],
              ),
            ),
          )
        else ...[
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: const Row(
              children: [
                _HeaderCell('DATE', flex: 11),
                _HeaderCell('ROUTE', flex: 8),
                _HeaderCell('DISTANCE', flex: 8),
                _HeaderCell('DURATION', flex: 8),
                _HeaderCell('MAX MACH', flex: 8),
                _HeaderCell('MAX ALT', flex: 7),
                _HeaderCell('FUEL', flex: 7),
                _HeaderCell('REHEAT', flex: 7),
                SizedBox(width: 36),
              ],
            ),
          ),
          for (final flight in flights) _LogRow(flight: flight, ref: ref),
        ],
      ],
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  const _HeaderCell(this.label, {required this.flex});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Expanded(
      flex: flex,
      child: Text(
        label,
        style: uiText(
          context,
          size: 10,
          color: colors.textDim,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final FlightLogEntry flight;
  final WidgetRef ref;
  const _LogRow({required this.flight, required this.ref});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasTouchdown = flight.touchdownVS != null;
    Color vsColor = colors.arrival;
    if (hasTouchdown) {
      final absVs = flight.touchdownVS!.abs();
      if (absVs > 500) {
        vsColor = colors.error;
      } else if (absVs > 250) {
        vsColor = colors.mvfr;
      }
    }
    final route = flight.departureIcao.isEmpty && flight.arrivalIcao.isEmpty
        ? '--'
        : '${flight.departureIcao.isEmpty ? '?' : flight.departureIcao}'
              '-${flight.arrivalIcao.isEmpty ? '?' : flight.arrivalIcao}';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 11,
            child: Text(
              flight.date,
              style: uiText(
                context,
                size: 12,
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              route,
              style: uiText(
                context,
                size: 12,
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              '${flight.distanceNm.round()} nm',
              style: uiText(
                context,
                size: 12,
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Tooltip(
              message: hasTouchdown
                  ? 'Touchdown: ${flight.touchdownVS!.round()} FPM / ${flight.touchdownPitch!.toStringAsFixed(1)}° / ${flight.touchdownGForce!.toStringAsFixed(2)}G'
                  : 'No touchdown recorded',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasTouchdown) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: vsColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _formatDuration(flight.durationSeconds),
                    style: uiText(
                      context,
                      size: 12,
                      color: colors.textPrimary,
                      weight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 8,
            child: Text(
              flight.maxMach != null
                  ? 'M${flight.maxMach!.toStringAsFixed(2)}'
                  : '--',
              style: uiText(
                context,
                size: 12,
                color: colors.accent,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              flight.maxAltitudeFt != null
                  ? numFormat.format(flight.maxAltitudeFt!.round())
                  : '--',
              style: uiText(
                context,
                size: 12,
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              flight.fuelBurnedKg != null
                  ? '${numFormat.format(flight.fuelBurnedKg!.round())} kg'
                  : '--',
              style: uiText(
                context,
                size: 12,
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: 7,
            child: Text(
              flight.reheatSeconds > 0
                  ? _formatDuration(flight.reheatSeconds)
                  : '--',
              style: uiText(
                context,
                size: 12,
                color: colors.textPrimary,
                weight: FontWeight.w600,
              ),
            ),
          ),
          SizedBox(
            width: 36,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Delete flight log',
                  icon: Icon(
                    Icons.delete_outline,
                    color: colors.error,
                    size: 18,
                  ),
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

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    FlightLogEntry flight,
  ) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: colors.dividerStrong),
        ),
        title: Text(
          'DELETE FLIGHT LOG?',
          style: uiText(
            context,
            size: 14,
            color: colors.textPrimary,
            weight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete the flight recording from ${flight.date}?',
          style: uiText(
            context,
            size: 12,
            color: colors.textSecondary,
            weight: FontWeight.w600,
            letterSpacing: 0,
          ),
        ),
        actions: [
          TextButton(
            child: Text(
              'CANCEL',
              style: uiText(
                context,
                size: 12,
                color: colors.textDim,
                letterSpacing: 0,
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: Text(
              'DELETE',
              style: uiText(
                context,
                size: 12,
                color: colors.error,
                weight: FontWeight.bold,
                letterSpacing: 0,
              ),
            ),
            onPressed: () {
              ref
                  .read(flightMonitorProvider.notifier)
                  .deleteFlightLogEntry(flight.id);
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }
}
