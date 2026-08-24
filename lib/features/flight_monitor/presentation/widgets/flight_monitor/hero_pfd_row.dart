import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../core/formatters.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';
import 'support_cards.dart';

/// Top row: airspeed/Mach and altitude/VS. Second row: the individual
/// attitude/heading/gear/droop stat cards, plus the engines/reheat panel.
class HeroPfdRow extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const HeroPfdRow({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final gearLabel = t.gearPosition <= 0.5
        ? 'UP'
        : (t.gearPosition >= 99.5 ? 'DOWN' : 'TRANSIT');
    final gearColor = gearLabel == 'DOWN'
        ? colors.arrival
        : (gearLabel == 'UP' ? colors.textPrimary : colors.mvfr);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 11, child: _AirspeedCard(t: t)),
              const SizedBox(width: 16),
              Expanded(flex: 11, child: _AltitudeCard(t: t)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _StatCard(
                  label: 'HDG',
                  value: '${t.heading.round()}°',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'PITCH',
                  value: '${t.pitch.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'ROLL',
                  value: '${t.roll.toStringAsFixed(1)}°',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'GEAR',
                  value: gearLabel,
                  valueColor: gearColor,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  label: 'DROOP/VISOR',
                  value: '${t.snootAngle.round()}°',
                ),
              ),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: EnginesReheatCard(t: t)),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatCard({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: uiText(
              context,
              size: 22,
              weight: FontWeight.w800,
              color: valueColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AirspeedCard extends StatelessWidget {
  final TelemetryModel t;
  const _AirspeedCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AIRSPEED / MACH',
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                t.ias.round().toString(),
                style: uiText(
                  context,
                  size: 52,
                  weight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KT IAS',
                style: uiText(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'M${t.mach.toStringAsFixed(2)}',
                style: uiText(
                  context,
                  size: 26,
                  color: colors.accent,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'TAS ${t.tas.round()} KT',
                style: uiText(
                  context,
                  size: 12,
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
}

class _AltitudeCard extends StatelessWidget {
  final TelemetryModel t;
  const _AltitudeCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vs = t.vs.round();
    final vsColor = vs > 100 ? colors.arrival : (vs < -100 ? colors.error : colors.textSecondary);
    final vsDisplay = (vs > 0 ? '+' : '') + vs.toString();

    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALTITUDE / VS',
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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                numFormat.format(t.altitude.round()),
                style: uiText(
                  context,
                  size: 52,
                  weight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FT',
                style: uiText(
                  context,
                  size: 13,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                vsDisplay,
                style: uiText(
                  context,
                  size: 26,
                  color: vsColor,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FPM  ·  GS ${t.gs.round()} KT',
                style: uiText(
                  context,
                  size: 12,
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
}

