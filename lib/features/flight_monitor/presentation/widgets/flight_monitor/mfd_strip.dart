import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/formatters.dart';
import '../../controllers/live_nav_provider.dart';
import '../../controllers/live_alerts_provider.dart';
import '../../controllers/alert_chime.dart';
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
    final destIcao = ref.watch(arrivalIcaoProvider);
    final fuelPlan = ref.watch(fuelBreakdownProvider);

    final nav = ref.watch(liveNavProvider);
    final phase = nav?.phase ?? FlightBurnPhase.ground;
    final pred = isLive ? nav?.prediction : null;

    final finalReserve = fuelPlan.finalReserveKg;
    final reservesWithAlt = finalReserve + fuelPlan.alternateKg;

    // --- annunciators ---
    final warnings = [
      for (final a in ref.watch(liveAlertsProvider)) (a.text, a.critical),
    ];

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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
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
                              // Tap a warning to silence its chime for
                              // 10 s on this device.
                              // DESCEND NOW / gear alerts clear outright (ATC,
                              // procedure or terrain may hold you level).
                              (w) => Tooltip(
                                message: clearableAlerts.contains(w.$1)
                                    ? 'Tap to clear (re-arms automatically)'
                                    : 'Tap to silence for 10 s',
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () => clearableAlerts.contains(w.$1)
                                      ? ref
                                            .read(
                                              dismissedAlertsProvider.notifier,
                                            )
                                            .dismiss(w.$1)
                                      : ref
                                            .read(alertChimeProvider.notifier)
                                            .silence(w.$1),
                                  child: _pill(
                                    context,
                                    w.$1,
                                    w.$2 ? colors.error : colors.accent,
                                    w.$2 ? Colors.white : AppColors.dark.bg,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                ),
              ),
              // Alert chime on/off (one chime per new alert, never a loop).
              IconButton(
                tooltip: ref.watch(alertChimeProvider)
                    ? 'Alert chimes on'
                    : 'Alert chimes muted',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  ref.watch(alertChimeProvider)
                      ? Icons.volume_up_outlined
                      : Icons.volume_off_outlined,
                  size: 18,
                  color: ref.watch(alertChimeProvider)
                      ? colors.accent
                      : colors.textDim,
                ),
                onPressed: () => ref
                    .read(alertChimeProvider.notifier)
                    .setEnabled(!ref.read(alertChimeProvider)),
              ),
            ],
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
