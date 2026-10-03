import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/concorde_constants.dart';
import '../../../../../core/concorde_logic.dart';
import '../../../../../core/formatters.dart';
import '../../../../../core/live_flight_math.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../models/concorde_models.dart';
import '../../../../../providers/efb_providers.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';

/// A cockpit-style MFD status strip: flight phase, distance to the planned
/// destination, top-of-descent, ETA, predicted landing fuel vs reserves,
/// plus an annunciator row for live warnings.
class MfdStrip extends ConsumerWidget {
  final TelemetryModel t;
  final double totalFuelKg;
  final double? fuelFlowKgH;
  final bool isLive;

  const MfdStrip({
    super.key,
    required this.t,
    required this.totalFuelKg,
    required this.fuelFlowKgH,
    required this.isLive,
  });

  static const _phaseLabel = {
    FlightBurnPhase.ground: 'GROUND',
    FlightBurnPhase.climb: 'CLIMB',
    FlightBurnPhase.reheatAccel: 'REHEAT',
    FlightBurnPhase.cruise: 'CRUISE',
    FlightBurnPhase.descent: 'DESCENT',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final dest = ref.watch(arrAirportProvider);
    final destIcao = ref.watch(arrivalIcaoProvider);
    final fuelPlan = ref.watch(fuelBreakdownProvider);

    final phase = ConcordeLogic.classifyBurnPhase(
      altitudeFt: t.altitude,
      vsFpm: t.vs,
      reheatActive: t.reheatActive,
    );
    final flow = (fuelFlowKgH ?? 0) >= 500
        ? fuelFlowKgH!
        : ConcordeLogic.phaseFuelFlowKgH(phase, t.altitude / 100);

    final pred = isLive && dest != null
        ? predictToDestination(
            lat: t.latitude,
            lon: t.longitude,
            destLat: dest.lat,
            destLon: dest.lon,
            altitudeFt: t.altitude,
            groundSpeedKt: t.gs,
            fuelFlowKgH: flow,
            fuelOnBoardKg: totalFuelKg,
          )
        : null;

    final finalReserve = fuelPlan.finalReserveKg;
    final reservesWithAlt = finalReserve + fuelPlan.alternateKg;

    // --- annunciators ---
    final warnings = <(String, bool)>[]; // (text, isCritical)
    if (isLive) {
      final cg = cgLimitsForMach(t.mach);
      if (t.cgPct > cg.aft) warnings.add(('CG AFT LIMIT', true));
      if (t.cgPct < cg.fwd) warnings.add(('CG FWD LIMIT', true));
      if (t.mach > ConcordeConstants.speeds.mmo) {
        warnings.add(('MACH > MMO', true));
      }
      if (t.gearLabel != 'UP' &&
          !t.onGround &&
          t.ias > ConcordeConstants.speeds.vleKt) {
        warnings.add(('GEAR SPEED', true));
      }
      if (pred != null && phase != FlightBurnPhase.ground) {
        if (pred.fuelAtDestKg < finalReserve) {
          warnings.add(('FUEL BELOW FINAL RESERVE AT DEST', true));
        } else if (pred.fuelAtDestKg < reservesWithAlt) {
          warnings.add(('NO ALTERNATE FUEL AT DEST', false));
        }
        if (pred.distToTodNm <= 10 &&
            pred.distToTodNm > -20 &&
            phase == FlightBurnPhase.cruise) {
          warnings.add(('DESCEND NOW', false));
        }
      }
      if (dest == null) warnings.add(('NO DESTINATION IN PLAN', false));
    }

    final todText = pred == null
        ? '--'
        : (pred.distToTodNm > 0
              ? '${numFormat.format(pred.distToTodNm.round())} NM'
              : 'PASSED');
    final etaText = pred == null ? '--' : _eta(t.zuluTime, pred.timeToDestH);
    final fuelColor = pred == null
        ? colors.textPrimary
        : (pred.fuelAtDestKg < finalReserve
              ? colors.error
              : (pred.fuelAtDestKg < reservesWithAlt
                    ? colors.accent
                    : colors.success));

    return EfbFlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _cell(
                context,
                'PHASE',
                isLive ? _phaseLabel[phase]! : '--',
                colors.accent,
              ),
              _cell(
                context,
                'TO ${destIcao.isEmpty ? 'DEST' : destIcao}',
                pred == null
                    ? '--'
                    : '${numFormat.format(pred.distToDestNm.round())} NM',
                colors.textPrimary,
              ),
              _cell(context, 'TOP OF DESCENT', todText, colors.textPrimary),
              _cell(context, 'ETA', etaText, colors.textPrimary),
              _cell(
                context,
                'FUEL AT DEST',
                pred == null
                    ? '--'
                    : '${numFormat.format(pred.fuelAtDestKg.round())} KG',
                fuelColor,
              ),
              _cell(
                context,
                'RESERVE + ALT',
                '${numFormat.format(reservesWithAlt.round())} KG',
                colors.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: colors.divider),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: !isLive
                ? [
                    _pill(
                      context,
                      'NO LIVE DATA',
                      colors.dividerStrong,
                      colors.textSecondary,
                    ),
                  ]
                : warnings.isEmpty
                ? [
                    _pill(
                      context,
                      'ALL SYSTEMS NORMAL',
                      colors.success,
                      AppColors.dark.bg,
                    ),
                  ]
                : warnings
                      .map(
                        (w) => _pill(
                          context,
                          w.$1,
                          w.$2 ? colors.error : colors.accent,
                          w.$2 ? Colors.white : AppColors.dark.bg,
                        ),
                      )
                      .toList(),
          ),
        ],
      ),
    );
  }

  static String _eta(String zulu, double hours) {
    final parts = zulu.split(':');
    if (parts.length < 2) return '--';
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final total = (h * 60 + m + (hours * 60).round()) % (24 * 60);
    return '${(total ~/ 60).toString().padLeft(2, '0')}'
        '${(total % 60).toString().padLeft(2, '0')}Z';
  }

  Widget _cell(BuildContext context, String label, String value, Color color) {
    final colors = context.colors;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: uiText(
                context,
                size: 16,
                weight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: uiText(
          context,
          size: 10,
          weight: FontWeight.w900,
          color: fg,
          letterSpacing: 1,
        ),
      ),
    );
  }
}
