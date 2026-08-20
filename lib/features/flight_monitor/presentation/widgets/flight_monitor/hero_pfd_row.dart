import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../core/formatters.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';

/// Top row: airspeed/Mach, altitude/VS, and a compact attitude+heading dial.
class HeroPfdRow extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const HeroPfdRow({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 11, child: _AirspeedCard(t: t)),
          const SizedBox(width: 16),
          Expanded(flex: 11, child: _AltitudeCard(t: t)),
          const SizedBox(width: 16),
          Expanded(flex: 14, child: _AttitudeCard(t: t)),
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

class _AttitudeCard extends StatelessWidget {
  final TelemetryModel t;
  const _AttitudeCard({required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ATTITUDE & HEADING',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HorizonDial(pitch: t.pitch),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'PITCH ${t.pitch.toStringAsFixed(1)}°',
                            style: uiText(
                              context,
                              size: 12,
                              color: colors.textSecondary,
                              weight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'ROLL ${t.roll.toStringAsFixed(1)}°',
                            style: uiText(
                              context,
                              size: 12,
                              color: colors.textSecondary,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${t.heading.round()}°',
                        style: uiText(
                          context,
                          size: 32,
                          weight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'HDG',
                        style: uiText(
                          context,
                          size: 11,
                          weight: FontWeight.w700,
                          color: colors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizonDial extends StatelessWidget {
  final double pitch;
  const _HorizonDial({required this.pitch});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final skyStop = (50 - pitch).clamp(0.0, 100.0);
    return Container(
      width: 96,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: colors.dividerStrong, width: 2),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: [0.0, skyStop / 100.0, skyStop / 100.0, 1.0],
                  colors: const [
                    Color(0xFF1D4E89),
                    Color(0xFF1D4E89),
                    Color(0xFF3A2410),
                    Color(0xFF3A2410),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 8,
            right: 8,
            top: 47,
            child: Container(height: 2, color: colors.accent),
          ),
        ],
      ),
    );
  }
}
