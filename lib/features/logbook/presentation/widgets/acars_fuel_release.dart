import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/formatters.dart';
import '../../../../core/ui_text.dart';
import '../../data/flight_log.dart';

/// Authentic cockpit ACARS dispatch thermal printout strip for fuel accounting.
class AcarsFuelReleaseStrip extends StatelessWidget {
  final FlightLog log;

  const AcarsFuelReleaseStrip({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    final actualTrip = (log.fuelTakeoffKg != null && log.fuelLandingKg != null)
        ? log.fuelTakeoffKg! - log.fuelLandingKg!
        : null;

    final plannedTrip = log.plannedTripKg > 0 ? log.plannedTripKg : null;

    final tripDelta = (actualTrip != null && plannedTrip != null && plannedTrip > 0)
        ? (actualTrip - plannedTrip)
        : null;
    final tripDeltaPct = (tripDelta != null && plannedTrip != null)
        ? (tripDelta / plannedTrip * 100)
        : null;

    final reserveMargin = log.fuelLandingKg == null
        ? null
        : log.fuelLandingKg! - (log.finalReserveKg > 0 ? log.finalReserveKg : 6500.0);

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ACARS DISPATCH FUEL AUDIT',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w900,
                      color: colors.accent,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Text(
                'SYS 42 · SIMBRIEF OFP',
                style: uiText(context, size: 9, color: colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _dashedDivider(colors),
          const SizedBox(height: 10),

          // Fuel rows with dot-matrix leaders
          _fuelRow(context, 'BLOCK OUT FUEL:', _kg(log.fuelBlockOutKg), colors),
          _fuelRow(context, 'TAKEOFF FUEL:', _kg(log.fuelTakeoffKg), colors),
          _fuelRow(context, 'LANDING FUEL:', _kg(log.fuelLandingKg), colors),
          _fuelRow(context, 'BLOCK IN FUEL:', _kg(log.fuelBlockInKg), colors),

          const SizedBox(height: 6),
          _dashedDivider(colors),
          const SizedBox(height: 6),

          _fuelRow(
            context,
            'ACTUAL TRIP BURN:',
            _kg(actualTrip),
            colors,
            valColor: colors.accent,
            isBold: true,
          ),
          _fuelRow(
            context,
            'PLANNED TRIP BURN:',
            _kg(plannedTrip),
            colors,
          ),
          if (tripDelta != null && tripDeltaPct != null)
            _fuelRow(
              context,
              'DELTA vs OFP PLAN:',
              '${tripDelta >= 0 ? '+' : '−'}${numFormat.format(tripDelta.abs().round())} KG (${tripDeltaPct >= 0 ? '+' : ''}${tripDeltaPct.toStringAsFixed(1)}%)',
              colors,
              valColor: tripDeltaPct.abs() <= 2.5 ? colors.success : colors.mvfr,
            ),

          const SizedBox(height: 6),
          _dashedDivider(colors),
          const SizedBox(height: 6),

          _fuelRow(
            context,
            'FINAL RESERVE MARGIN:',
            reserveMargin == null
                ? '--'
                : '${reserveMargin >= 0 ? '+' : '−'}${numFormat.format(reserveMargin.abs().round())} KG ${reserveMargin >= 0 ? '(SAFE)' : '(MIN EXCEEDED)'}',
            colors,
            valColor: reserveMargin == null
                ? null
                : (reserveMargin >= 0 ? colors.success : colors.error),
            isBold: true,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'MANDATORY MINIMUM: ${numFormat.format((log.finalReserveKg > 0 ? log.finalReserveKg : 6500).round())} KG',
              style: uiText(context, size: 8, color: colors.textDim),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fuelRow(
    BuildContext context,
    String label,
    String val,
    AppColors colors, {
    Color? valColor,
    bool isBold = false,
  }) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            Text(
              label,
              style: uiText(
                context,
                size: 11,
                weight: isBold ? FontWeight.w900 : FontWeight.w700,
                color: isBold ? colors.textPrimary : colors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final dotCount = (c.maxWidth / 8).floor();
                  if (dotCount <= 0) return const SizedBox();
                  return Text(
                    '.' * dotCount,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: colors.dividerStrong.withValues(alpha: 0.35),
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Text(
              val,
              style: uiText(
                context,
                size: 12,
                weight: FontWeight.w900,
                color: valColor ?? colors.textPrimary,
              ),
            ),
          ],
        ),
      );

  Widget _dashedDivider(AppColors colors) => LayoutBuilder(
        builder: (context, c) {
          final dashCount = (c.maxWidth / 6).floor();
          return Text(
            '-' * dashCount,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: colors.dividerStrong.withValues(alpha: 0.4),
              fontSize: 10,
              letterSpacing: 1,
            ),
          );
        },
      );

  String _kg(double? v) =>
      v == null ? '--' : '${numFormat.format(v.round())} KG';
}
