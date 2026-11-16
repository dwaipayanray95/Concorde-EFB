import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/formatters.dart';
import '../../../../core/ui_text.dart';
import '../../data/flight_log.dart';
import '../logbook_format.dart';

/// Measured Runway Performance vs Planner Aerodynamic Prediction Card.
/// Displays measured ground roll distance against the prediction and runway length,
/// with visual proportional runway bars, 1-second rollout trace metrics, and touchdown dynamics.
class RunwayPerformanceCard extends StatelessWidget {
  final FlightLog log;

  const RunwayPerformanceCard({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final to = log.takeoffPerf;
    final ld = log.landingPerf;

    if (to == null && ld == null) {
      return const SizedBox();
    }

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
                      color: colors.success,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'MEASURED RUNWAY PERFORMANCE vs MODEL',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w900,
                      color: colors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.resultsBg,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: colors.dividerStrong.withValues(alpha: 0.6),
                  ),
                ),
                child: Text(
                  '1-SEC TRACE TELEMETRY',
                  style: uiText(
                    context,
                    size: 8,
                    weight: FontWeight.w800,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Takeoff Section
          if (to != null) ...[
            _takeoffSection(context, to, colors),
            const SizedBox(height: 12),
          ],

          // Landing Section
          if (ld != null) ...[
            _landingSection(context, ld, colors),
          ],
        ],
      ),
    );
  }

  Widget _takeoffSection(
    BuildContext context,
    Map<String, dynamic> to,
    AppColors colors,
  ) {
    final plan = (to['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    final actualM = (to['rollM'] as num?)?.toDouble();
    final predictedM = (plan['requiredM'] as num?)?.toDouble();
    final rwyLengthM = (plan['runwayLengthM'] as num?)?.toDouble() ?? 3600.0;
    final rwy = plan['runway'] != null
        ? '${plan['icao'] ?? ''} RWY ${plan['runway']}'
        : '';
    final rollSec = (to['rollSec'] as num?)?.toDouble();
    final liftoffIas = (to['liftoffIas'] as num?)?.toDouble();
    final liftoffGs = (to['liftoffGs'] as num?)?.toDouble();
    final reheatCount = (to['reheat'] as num?)?.toInt() ?? 4;
    final tow = (to['towKg'] as num?)?.toDouble() ?? log.towKg;

    final diffPct = (actualM != null && predictedM != null && predictedM > 0)
        ? ((actualM - predictedM) / predictedM * 100)
        : null;

    final spareM = (actualM != null && rwyLengthM > actualM)
        ? (rwyLengthM - actualM)
        : null;

    final rollFrac = (actualM != null && rwyLengthM > 0)
        ? (actualM / rwyLengthM).clamp(0.05, 1.0)
        : 0.70;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAKEOFF GROUND ROLL ($rwy${tow != null ? ' · TOW ${numFormat.format(tow.round())} KG' : ''})',
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w900,
                  color: colors.accent,
                ),
              ),
              if (diffPct != null)
                Text(
                  '${diffPct >= 0 ? '+' : ''}${diffPct.toStringAsFixed(1)}% vs PREDICTION',
                  style: uiText(
                    context,
                    size: 9,
                    weight: FontWeight.w800,
                    color: diffPct <= 0 ? colors.success : colors.mvfr,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 4 Metric Columns
          Row(
            children: [
              Expanded(
                child: _dataCol(
                  context,
                  'PREDICTED ROLL',
                  predictedM != null ? '${numFormat.format(predictedM.round())} M' : '--',
                  colors,
                ),
              ),
              Expanded(
                child: _dataCol(
                  context,
                  'ACTUAL ROLL',
                  actualM != null
                      ? '${numFormat.format(actualM.round())} M${rollSec != null ? ' (${rollSec.round()}s)' : ''}'
                      : '--',
                  colors,
                  valColor: colors.accent,
                ),
              ),
              Expanded(
                child: _dataCol(
                  context,
                  'LIFT-OFF SPEEDS',
                  liftoffIas != null
                      ? '${liftoffIas.round()} IAS · ${(liftoffGs ?? 0).round()} GS'
                      : '--',
                  colors,
                ),
              ),
              Expanded(
                child: _dataCol(
                  context,
                  'REMAINING SPARE',
                  spareM != null ? '${numFormat.format(spareM.round())} M' : '--',
                  colors,
                  valColor: colors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Runway Proportional Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 14,
              color: colors.bg,
              child: Row(
                children: [
                  Expanded(
                    flex: (rollFrac * 100).round(),
                    child: Container(
                      color: colors.accent,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        actualM != null
                            ? 'ROLL: ${numFormat.format(actualM.round())}M ($reheatCount× REHEAT)'
                            : 'ROLL',
                        maxLines: 1,
                        style: uiText(
                          context,
                          size: 8,
                          weight: FontWeight.w900,
                          color: AppColors.dark.bg,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1.0 - rollFrac) * 100).round(),
                    child: Container(
                      color: colors.success.withValues(alpha: 0.25),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        spareM != null
                            ? 'SPARE: ${numFormat.format(spareM.round())}M'
                            : 'SPARE',
                        maxLines: 1,
                        style: uiText(
                          context,
                          size: 8,
                          weight: FontWeight.w900,
                          color: colors.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _landingSection(
    BuildContext context,
    Map<String, dynamic> ld,
    AppColors colors,
  ) {
    final plan = (ld['plan'] as Map?)?.cast<String, dynamic>() ?? const {};
    final rollToExitM = (ld['rollToExitM'] as num?)?.toDouble();
    final rollToExitSec = (ld['rollToExitSec'] as num?)?.toDouble();
    final predictedM = (plan['requiredM'] as num?)?.toDouble();
    final rwyLengthM = (plan['runwayLengthM'] as num?)?.toDouble() ?? 3800.0;
    final rwy = plan['runway'] != null
        ? '${plan['icao'] ?? ''} RWY ${plan['runway']}'
        : '';
    final touchdownIas = (ld['touchdownIas'] as num?)?.toDouble() ?? log.touchdownIas;
    final rating = log.landingRating;

    final rollFrac = (rollToExitM != null && rwyLengthM > 0)
        ? (rollToExitM / rwyLengthM).clamp(0.05, 1.0)
        : 0.50;
    final spareM = (rollToExitM != null && rwyLengthM > rollToExitM)
        ? (rwyLengthM - rollToExitM)
        : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.resultsBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'LANDING ROLLOUT ($rwy${rating != null ? ' · ${rating.label}' : ''})',
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w900,
                  color: colors.departure,
                ),
              ),
              if (log.touchdownFpm != null)
                Text(
                  '${fpmText(log.touchdownFpm!)} · ${log.touchdownG?.toStringAsFixed(2) ?? '1.0'} G',
                  style: uiText(
                    context,
                    size: 9,
                    weight: FontWeight.w800,
                    color: colors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 4 Metric Columns
          Row(
            children: [
              Expanded(
                child: _dataCol(
                  context,
                  'RATE OF DESCENT',
                  log.touchdownFpm != null ? fpmText(log.touchdownFpm!) : '--',
                  colors,
                  valColor: colors.success,
                ),
              ),
              Expanded(
                child: _dataCol(
                  context,
                  'PITCH / IAS',
                  '${log.touchdownPitch?.toStringAsFixed(1) ?? '--'}° · ${touchdownIas?.round() ?? '--'} KT',
                  colors,
                ),
              ),
              Expanded(
                child: _dataCol(
                  context,
                  'ROLL TO 30 KT EXIT',
                  rollToExitM != null
                      ? '${numFormat.format(rollToExitM.round())} M${rollToExitSec != null ? ' (${rollToExitSec.round()}s)' : ''}'
                      : (predictedM != null ? '${numFormat.format(predictedM.round())} M (EST)' : '--'),
                  colors,
                  valColor: const Color(0xFF06B6D4),
                ),
              ),
              Expanded(
                child: _dataCol(
                  context,
                  'BOUNCES / GO-AROUNDS',
                  '${log.bounces} BNC · ${log.goArounds} G/A',
                  colors,
                  valColor: log.bounces == 0 && log.goArounds == 0
                      ? colors.success
                      : colors.mvfr,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Visual Landing Runway Proportional Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 14,
              color: colors.bg,
              child: Row(
                children: [
                  Expanded(
                    flex: (rollFrac * 100).round(),
                    child: Container(
                      color: const Color(0xFF06B6D4),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        rollToExitM != null
                            ? 'ROLLOUT: ${numFormat.format(rollToExitM.round())}M'
                            : 'ROLLOUT',
                        maxLines: 1,
                        style: uiText(
                          context,
                          size: 8,
                          weight: FontWeight.w900,
                          color: AppColors.dark.bg,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: ((1.0 - rollFrac) * 100).round(),
                    child: Container(
                      color: colors.success.withValues(alpha: 0.25),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        spareM != null
                            ? 'SPARE: ${numFormat.format(spareM.round())}M (${numFormat.format(rwyLengthM.round())}M RWY)'
                            : 'SPARE',
                        maxLines: 1,
                        style: uiText(
                          context,
                          size: 8,
                          weight: FontWeight.w900,
                          color: colors.success,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataCol(
    BuildContext context,
    String label,
    String val,
    AppColors colors, {
    Color? valColor,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiText(
              context,
              size: 8,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              val,
              style: uiText(
                context,
                size: 13,
                weight: FontWeight.w900,
                color: valColor ?? colors.textPrimary,
              ),
            ),
          ),
        ],
      );
}
