import 'package:flutter/material.dart';
import '../../../../../core/formatters.dart';
import '../../../data/models/telemetry_model.dart';
import 'fm_theme.dart';

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
    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AIRSPEED / MACH', style: fmLabel()),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(t.ias.round().toString(), style: fmMono(size: 52)),
              const SizedBox(width: 8),
              Text('KT IAS', style: fmLabel(size: 13, weight: FontWeight.w700, letterSpacing: 0)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('M${t.mach.toStringAsFixed(2)}', style: fmMono(size: 26, color: fmAccent, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('TAS ${t.tas.round()} KT', style: fmLabel(size: 12, weight: FontWeight.w700, letterSpacing: 0)),
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
    final vs = t.vs.round();
    final vsColor = vs > 100 ? fmGreen : (vs < -100 ? fmRed : fmTextSecondary);
    final vsDisplay = (vs > 0 ? '+' : '') + vs.toString();

    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ALTITUDE / VS', style: fmLabel()),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(numFormat.format(t.altitude.round()), style: fmMono(size: 52)),
              const SizedBox(width: 8),
              Text('FT', style: fmLabel(size: 13, weight: FontWeight.w700, letterSpacing: 0)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(vsDisplay, style: fmMono(size: 26, color: vsColor, weight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('FPM  ·  GS ${t.gs.round()} KT', style: fmLabel(size: 12, weight: FontWeight.w700, letterSpacing: 0)),
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
    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ATTITUDE & HEADING', style: fmLabel()),
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
                          Text('PITCH ${t.pitch.toStringAsFixed(1)}°', style: fmMono(size: 12, color: fmTextSecondary, weight: FontWeight.w700)),
                          Text('ROLL ${t.roll.toStringAsFixed(1)}°', style: fmMono(size: 12, color: fmTextSecondary, weight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('${t.heading.round()}°', style: fmMono(size: 32)),
                      const SizedBox(height: 4),
                      Text('HDG', style: fmLabel(size: 11, weight: FontWeight.w700, letterSpacing: 0)),
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
    // Sky above / ground below the horizon line, shifted by pitch — mirrors
    // the design's CSS gradient split exactly.
    final skyStop = (50 - pitch).clamp(0.0, 100.0);
    return Container(
      width: 96,
      height: 96,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: fmBorder, width: 2),
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
            child: Container(height: 2, color: fmAccent),
          ),
        ],
      ),
    );
  }
}
