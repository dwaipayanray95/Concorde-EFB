import '../../controllers/telemetry_provider.dart';
import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../core/concorde_logic.dart';
import '../../../../../models/concorde_models.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';

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

  /// Smoothed actual sim fuel flow (kg/h), null before the first frame.
  final double? fuelFlowKgH;
  const FuelBurnCard({
    super.key,
    required this.t,
    required this.totalFuelKg,
    this.fuelFlowKgH,
  });

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
    // Endurance uses the sim's own (smoothed) fuel flow; the phase table is
    // only a fallback before any real flow has been seen (e.g. engines off).
    final actual = fuelFlowKgH ?? 0;
    final flowKgH = actual >= 500
        ? actual
        : ConcordeLogic.phaseFuelFlowKgH(phase, t.altitude / 100);
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
            (fuelFlowKgH ?? t.fuelBurnTotal).round().toString(),
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
  final TouchdownRecord? touchdown;
  const TouchdownCard({super.key, required this.touchdown});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final td = touchdown;
    final hasTouchdown = td != null;
    final vs = td?.vsFpm.round();
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
                ? 'PITCH ${td.pitchDeg.toStringAsFixed(1)}° · ${td.gForce.toStringAsFixed(2)}G · ${td.zulu}Z'
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

/// GEAR · FLAPS · DROOP NOSE · VISOR card (spans 2 columns).
