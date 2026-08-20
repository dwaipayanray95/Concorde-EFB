import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../core/concorde_logic.dart';
import '../../../../../models/concorde_models.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';

/// CENTER OF GRAVITY compact card.
class CgCard extends StatelessWidget {
  final TelemetryModel t;
  const CgCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final warn = t.cgPct > t.cgAftLimit - 1.5 || t.cgPct < t.cgFwdLimit + 1.5;
    final color = warn ? colors.error : colors.textPrimary;
    final range = t.cgAftLimit - t.cgFwdLimit;
    final markerPct = range > 0
        ? ((t.cgPct - t.cgFwdLimit) / range * 100).clamp(0.0, 100.0)
        : 0.0;

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      accentTop: warn ? colors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CENTER OF GRAVITY',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${t.cgPct.toStringAsFixed(1)}%',
            style: uiText(
              context,
              size: 24,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 6,
                decoration: BoxDecoration(
                  color: colors.inputBg,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Positioned(
                left: 0,
                top: -2,
                right: 0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: Align(
                    alignment: Alignment(markerPct / 50 - 1, 0),
                    child: Container(width: 2, height: 10, color: color),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'FWD ${t.cgFwdLimit.toStringAsFixed(1)}',
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                  letterSpacing: 0,
                ),
              ),
              Text(
                'AFT ${t.cgAftLimit.toStringAsFixed(1)}',
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                  letterSpacing: 0,
                ),
              ),
            ],
          ),
          if (warn) ...[
            const SizedBox(height: 8),
            Text(
              '⚠ NEAR LIMIT',
              style: uiText(
                context,
                size: 9,
                color: colors.error,
                weight: FontWeight.w800,
                letterSpacing: 0,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// ENVIRONMENTAL compact card: SAT, TAT, icing.
class EnvironmentalCard extends StatelessWidget {
  final TelemetryModel t;
  const EnvironmentalCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final icingIdx = t.tat <= 2 ? (t.tat <= -10 ? 2 : 1) : 0;
    const icingLabels = ['NIL', 'POSSIBLE', 'ACTIVE'];
    final icingColors = [colors.textPrimary, colors.mvfr, colors.error];

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENVIRONMENTAL',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _kvRow(context, 'SAT', '${t.sat.round()}°C'),
          const SizedBox(height: 6),
          _kvRow(context, 'TAT', '${t.tat.round()}°C'),
          const SizedBox(height: 6),
          _kvRow(
            context,
            'ICING',
            icingLabels[icingIdx],
            valueColor: icingColors[icingIdx],
            valueSize: 11,
          ),
        ],
      ),
    );
  }

  Widget _kvRow(
    BuildContext context,
    String k,
    String v, {
    Color? valueColor,
    double valueSize = 14,
  }) {
    final colors = context.colors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          k,
          style: uiText(
            context,
            size: 10,
            color: colors.textDim,
            weight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        Text(
          v,
          style: uiText(
            context,
            size: valueSize,
            weight: FontWeight.bold,
            color: valueColor ?? colors.textPrimary,
          ),
        ),
      ],
    );
  }
}

extension on TelemetryModel {
  double get sat {
    final tatK = tat + 273.15;
    final satK = tatK / (1 + 0.2 * mach * mach);
    return satK - 273.15;
  }
}

/// FUEL BURN RATE compact card.
class FuelBurnCard extends StatelessWidget {
  final TelemetryModel t;
  final double totalFuelKg;
  const FuelBurnCard({super.key, required this.t, required this.totalFuelKg});

  static const _phaseLabel = {
    FlightBurnPhase.ground: 'GROUND',
    FlightBurnPhase.climb: 'CLIMB',
    FlightBurnPhase.reheatAccel: 'REHEAT',
    FlightBurnPhase.cruise: 'CRUISE',
    FlightBurnPhase.descent: 'DESCENT',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final phase = ConcordeLogic.classifyBurnPhase(
      altitudeFt: t.altitude,
      vsFpm: t.vs,
      reheatActive: t.reheatActive,
    );
    final flowKgH = ConcordeLogic.phaseFuelFlowKgH(phase, t.altitude / 100);
    final airtime = flowKgH > 0
        ? '${(totalFuelKg / flowKgH).toStringAsFixed(1)} HRS'
        : '—';
    final flText = phase == FlightBurnPhase.ground
        ? ''
        : ' · FL${(t.altitude / 100).round()}';

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FUEL BURN RATE',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.fuelBurnTotal.round().toString(),
            style: uiText(
              context,
              size: 24,
              weight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'KG/HR',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: colors.textDim,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'EST. AIRTIME $airtime',
            style: uiText(
              context,
              size: 10,
              color: colors.accent,
              weight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'AT ${_phaseLabel[phase]}$flText',
            style: uiText(
              context,
              size: 9,
              color: colors.textDim,
              weight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

/// LANDING TOUCHDOWN compact card.
class TouchdownCard extends StatelessWidget {
  final TelemetryModel t;
  const TouchdownCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final hasTouchdown = t.isLanding;
    final vs = hasTouchdown ? t.touchdownVS.round() : null;
    final color = vs == null
        ? colors.textPrimary
        : (vs < -600
            ? colors.error
            : (vs < -400 ? colors.mvfr : colors.arrival));

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      accentTop: vs != null && vs < -600 ? colors.error : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LANDING TOUCHDOWN',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            vs?.toString() ?? '—',
            style: uiText(
              context,
              size: 24,
              weight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'FPM',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w700,
              color: colors.textDim,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            hasTouchdown
                ? 'PITCH ${t.touchdownPitch.toStringAsFixed(1)}° · ${t.touchdownGForce.toStringAsFixed(2)}G'
                : '—',
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w700,
              color: colors.textDim,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

/// G-FORCE compact card.
class GForceCard extends StatelessWidget {
  final TelemetryModel t;
  const GForceCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'G-FORCE',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            t.gForce.toStringAsFixed(2),
            style: uiText(
              context,
              size: 24,
              weight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// ENGINES / REHEAT card (spans 2 columns).
class EnginesReheatCard extends StatelessWidget {
  final TelemetryModel t;
  const EnginesReheatCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ENGINES / REHEAT',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: List.generate(4, (i) {
              final on = i < t.reheatActive.length && t.reheatActive[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: on ? colors.mvfrBg : colors.inputBg,
                      border: Border.all(
                        color: on
                            ? colors.mvfr.withValues(alpha: 0.5)
                            : colors.dividerStrong,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Column(
                      children: [
                        Text(
                          'ENG ${i + 1}',
                          style: uiText(
                            context,
                            size: 10,
                            weight: FontWeight.w800,
                            color: on ? colors.mvfr : colors.textDim,
                            letterSpacing: 0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          on ? 'REHEAT' : 'DRY',
                          style: uiText(
                            context,
                            size: 13,
                            weight: FontWeight.bold,
                            color: on ? colors.mvfr : colors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// GEAR · FLAPS · DROOP NOSE · VISOR card (spans 2 columns).
class GearFlapsDroopCard extends StatelessWidget {
  final TelemetryModel t;
  const GearFlapsDroopCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gearLabel = t.gearPosition <= 0.5
        ? 'UP'
        : (t.gearPosition >= 99.5 ? 'DOWN' : 'TRANSIT');
    final gearColor = gearLabel == 'DOWN'
        ? colors.arrival
        : (gearLabel == 'UP' ? colors.textPrimary : colors.mvfr);
    final flapsLabel = t.flapsPosition == 0 ? 'UP' : t.flapsPosition.toString();

    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GEAR · FLAPS · DROOP NOSE · VISOR',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat(context, 'GEAR', gearLabel, gearColor)),
              Expanded(child: _stat(context, 'FLAPS', flapsLabel, colors.textPrimary)),
              Expanded(
                child: _stat(
                  context,
                  'DROOP',
                  '${t.snootAngle.round()}°',
                  colors.textPrimary,
                ),
              ),
              Expanded(
                child: _stat(
                  context,
                  'VISOR/SNOOT',
                  '${t.snootAngle.round()}°',
                  colors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value, Color color) {
    final colors = context.colors;
    return Column(
      children: [
        Text(
          label,
          style: uiText(
            context,
            size: 10,
            weight: FontWeight.w800,
            color: colors.textDim,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: uiText(
            context,
            size: 14,
            weight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
