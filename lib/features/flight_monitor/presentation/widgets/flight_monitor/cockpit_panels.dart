import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/formatters.dart';
import '../../../../../core/live_flight_math.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../providers/efb_providers.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';
import '../../controllers/live_nav_provider.dart';

Text _label(BuildContext context, String text) => Text(
  text,
  style: uiText(
    context,
    size: 10,
    weight: FontWeight.w800,
    color: context.colors.textDim,
    letterSpacing: 1.2,
  ),
);

// ---------------------------------------------------------------------------
// Flight progress: DEP ━━━✈━━━ TOD ━━ ARR along the planned route.
// ---------------------------------------------------------------------------

class FlightProgressBar extends ConsumerWidget {
  const FlightProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final nav = ref.watch(liveNavProvider);
    final dep = ref.watch(departureIcaoProvider);
    final arr = ref.watch(arrivalIcaoProvider);
    final pred = nav?.prediction;
    final progress = nav?.progress ?? 0;
    final tod = nav?.todProgress;

    final caption = pred == null
        ? 'WAITING FOR LIVE POSITION'
        : '${numFormat.format(pred.distToDestNm.round())} NM TO GO'
              '${pred.distToTodNm > 0 ? '  ·  TOD IN ${numFormat.format(pred.distToTodNm.round())} NM' : '  ·  PAST TOD'}';

    TextStyle icao(Color c) =>
        uiText(context, size: 13, weight: FontWeight.w900, color: c);

    return EfbFlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(dep.isEmpty ? '----' : dep, style: icao(colors.success)),
              const SizedBox(width: 14),
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final w = c.maxWidth;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.dividerStrong,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Container(
                            height: 4,
                            width: w * progress,
                            decoration: BoxDecoration(
                              color: colors.accent,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          if (tod != null)
                            Positioned(
                              left: w * tod - 5,
                              child: Transform.rotate(
                                angle: math.pi / 4,
                                child: Container(
                                  width: 10,
                                  height: 10,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ),
                          if (pred != null)
                            Positioned(
                              left: (w * progress - 11).clamp(-11.0, w - 11),
                              child: Transform.rotate(
                                angle: math.pi / 2,
                                child: Icon(
                                  Icons.flight,
                                  size: 22,
                                  color: colors.accent,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Text(arr.isEmpty ? '----' : arr, style: icao(colors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            caption,
            textAlign: TextAlign.center,
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w800,
              color: colors.textSecondary,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Engines: four vertical throttle bars with reheat lights + total flow.
// ---------------------------------------------------------------------------

class EnginesPanel extends StatelessWidget {
  final TelemetryModel t;
  final double? fuelFlowKgH;
  const EnginesPanel({super.key, required this.t, this.fuelFlowKgH});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final anyReheat = t.reheatActive.any((r) => r);
    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: _label(context, 'ENGINES')),
              if (anyReheat)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.accent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'REHEAT',
                    style: uiText(
                      context,
                      size: 9,
                      weight: FontWeight.w900,
                      color: AppColors.dark.bg,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: _engineBar(context, i)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: colors.divider),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _label(context, 'TOTAL FUEL FLOW'),
              const Spacer(),
              Text(
                numFormat.format((fuelFlowKgH ?? t.fuelBurnTotal).round()),
                style: uiText(
                  context,
                  size: 18,
                  weight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'KG/H',
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _engineBar(BuildContext context, int i) {
    final colors = context.colors;
    final throttle = (i < t.throttlePct.length ? t.throttlePct[i] : 0.0).clamp(
      0.0,
      100.0,
    );
    final reheat = i < t.reheatActive.length && t.reheatActive[i];
    final barColor = reheat
        ? colors.accent
        : (throttle > 2 ? colors.success : colors.dividerStrong);
    return Column(
      children: [
        Text(
          '${throttle.round()}%',
          style: uiText(
            context,
            size: 13,
            weight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: Container(
            width: 26,
            decoration: BoxDecoration(
              color: colors.inputBg,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: colors.dividerStrong.withValues(alpha: 0.6),
              ),
            ),
            alignment: Alignment.bottomCenter,
            child: FractionallySizedBox(
              heightFactor: throttle / 100,
              widthFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: barColor,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Reheat light: lit amber when that engine's afterburner is on.
        Container(
          width: 30,
          padding: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: reheat ? colors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: reheat ? colors.accent : colors.dividerStrong,
            ),
          ),
          child: Text(
            'RH',
            textAlign: TextAlign.center,
            style: uiText(
              context,
              size: 8,
              weight: FontWeight.w900,
              color: reheat ? AppColors.dark.bg : colors.textDim,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ENG ${i + 1}',
          style: uiText(
            context,
            size: 9,
            weight: FontWeight.w800,
            color: colors.textDim,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// CG + trim: corridor for the current Mach, target, transfer advice.
// ---------------------------------------------------------------------------

class CgTrimCard extends StatelessWidget {
  final TelemetryModel t;
  const CgTrimCard({super.key, required this.t});

  static const _scaleMin = 50.0;
  static const _scaleMax = 62.0;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final lim = cgLimitsForMach(t.mach);
    // Fly the CG in the aft part of the corridor (less trim drag), but
    // keep a margin from the aft limit.
    final target = lim.fwd + (lim.aft - lim.fwd) * 0.6;
    final cg = t.cgPct;
    final outside = cg < lim.fwd || cg > lim.aft;
    final (advice, adviceColor) = outside
        ? (
            cg < lim.fwd
                ? 'CG FWD LIMIT — TRANSFER AFT'
                : 'CG AFT LIMIT — TRANSFER FWD',
            colors.error,
          )
        : (cg < target - 0.5)
        ? ('TRANSFER AFT', colors.accent)
        : (cg > target + 0.5)
        ? ('TRANSFER FWD', colors.accent)
        : ('CG ON TARGET', colors.success);

    double x(double pct, double w) =>
        ((pct - _scaleMin) / (_scaleMax - _scaleMin)).clamp(0.0, 1.0) * w;

    final fwdTrimKg = (t.fuelTanksKg['9'] ?? 0) + (t.fuelTanksKg['10'] ?? 0);
    final aftTrimKg = t.fuelTanksKg['11'] ?? 0;

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      accentTop: outside ? colors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              _label(context, 'CENTRE OF GRAVITY'),
              const Spacer(),
              Text(
                '${cg.toStringAsFixed(1)}%',
                style: uiText(
                  context,
                  size: 22,
                  weight: FontWeight.w800,
                  color: outside ? colors.error : colors.textPrimary,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'MAC',
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 30,
            child: LayoutBuilder(
              builder: (context, c) {
                final w = c.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 10,
                      left: 0,
                      right: 0,
                      child: Container(height: 10, color: colors.inputBg),
                    ),
                    // Allowed corridor at this Mach.
                    Positioned(
                      top: 10,
                      left: x(lim.fwd, w),
                      width: x(lim.aft, w) - x(lim.fwd, w),
                      child: Container(
                        height: 10,
                        color: colors.success.withValues(alpha: 0.35),
                      ),
                    ),
                    // Target.
                    Positioned(
                      top: 6,
                      left: x(target, w) - 1,
                      child: Container(
                        width: 2,
                        height: 18,
                        color: colors.success,
                      ),
                    ),
                    // Actual CG.
                    Positioned(
                      top: 0,
                      left: x(cg, w) - 6,
                      child: Icon(
                        Icons.arrow_drop_down,
                        size: 14,
                        color: outside ? colors.error : colors.accent,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      left: x(cg, w) - 1.5,
                      child: Container(
                        width: 3,
                        height: 14,
                        color: outside ? colors.error : colors.accent,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Row(
            children: [
              Text(
                'FWD ${lim.fwd.toStringAsFixed(1)}',
                style: uiText(context, size: 9, color: colors.textDim),
              ),
              const Spacer(),
              Text(
                'TARGET ${target.toStringAsFixed(1)} @ M${t.mach.toStringAsFixed(2)}',
                style: uiText(context, size: 9, color: colors.success),
              ),
              const Spacer(),
              Text(
                'AFT ${lim.aft.toStringAsFixed(1)}',
                style: uiText(context, size: 9, color: colors.textDim),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: adviceColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              advice,
              textAlign: TextAlign.center,
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w900,
                color: adviceColor == colors.accent
                    ? AppColors.dark.bg
                    : Colors.white,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _trim(context, 'FWD TRIM 9+10', fwdTrimKg)),
              const SizedBox(width: 12),
              Expanded(child: _trim(context, 'AFT TRIM 11', aftTrimKg)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _trim(BuildContext context, String label, double kg) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(context, label),
        const SizedBox(height: 2),
        Text(
          '${numFormat.format(kg.round())} KG',
          style: uiText(
            context,
            size: 14,
            weight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ],
    );
  }
}
