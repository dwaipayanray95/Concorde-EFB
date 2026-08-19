import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'fm_theme.dart';

/// CENTER OF GRAVITY compact card.
class CgCard extends StatelessWidget {
  final TelemetryModel t;
  const CgCard({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final warn = t.cgPct > t.cgAftLimit - 1.5 || t.cgPct < t.cgFwdLimit + 1.5;
    final color = warn ? fmRed : fmTextPrimary;
    final range = t.cgAftLimit - t.cgFwdLimit;
    final markerPct = range > 0 ? ((t.cgPct - t.cgFwdLimit) / range * 100).clamp(0.0, 100.0) : 0.0;

    return Container(
      decoration: fmCardDecoration(border: warn ? fmRedDeep : fmBorder),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('CENTER OF GRAVITY', style: fmLabel(size: 10, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text('${t.cgPct.toStringAsFixed(1)}%', style: fmMono(size: 24, color: color)),
          const SizedBox(height: 10),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(height: 6, decoration: BoxDecoration(color: const Color(0xFF141B29), borderRadius: BorderRadius.circular(4))),
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
              Text('FWD ${t.cgFwdLimit.toStringAsFixed(1)}', style: fmLabel(size: 9, weight: FontWeight.w700, letterSpacing: 0)),
              Text('AFT ${t.cgAftLimit.toStringAsFixed(1)}', style: fmLabel(size: 9, weight: FontWeight.w700, letterSpacing: 0)),
            ],
          ),
          if (warn) ...[
            const SizedBox(height: 8),
            Text('⚠ NEAR LIMIT', style: fmLabel(size: 9, color: fmRed, weight: FontWeight.w800, letterSpacing: 0)),
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
    // No dedicated icing simvar is streamed yet; infer a coarse risk band
    // from total air temperature so the indicator isn't just a dead "NIL".
    final icingIdx = t.tat <= 2 ? (t.tat <= -10 ? 2 : 1) : 0;
    const icingLabels = ['NIL', 'POSSIBLE', 'ACTIVE'];
    const icingColors = [fmTextPrimary, fmAmber, fmRed];

    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENVIRONMENTAL', style: fmLabel(size: 10, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          _kvRow('SAT', '${t.sat.round()}°C'),
          const SizedBox(height: 6),
          _kvRow('TAT', '${t.tat.round()}°C'),
          const SizedBox(height: 6),
          _kvRow('ICING', icingLabels[icingIdx], valueColor: icingColors[icingIdx], valueSize: 11),
        ],
      ),
    );
  }

  Widget _kvRow(String k, String v, {Color valueColor = fmTextPrimary, double valueSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(k, style: fmLabel(size: 10, color: fmTextSecondary, weight: FontWeight.w700, letterSpacing: 0)),
        Text(v, style: fmMono(size: valueSize, color: valueColor)),
      ],
    );
  }
}

extension on TelemetryModel {
  /// SAT isn't streamed by the bridge (only TAT is) — recover it from the
  /// standard ram-rise relation TAT = SAT * (1 + 0.2 * M^2) (recovery
  /// factor of 1, in Kelvin) rather than approximating in Celsius directly.
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

  @override
  Widget build(BuildContext context) {
    final airtime = t.fuelBurnTotal > 0 ? '${(totalFuelKg / t.fuelBurnTotal).toStringAsFixed(1)} HRS' : '—';

    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FUEL BURN RATE', style: fmLabel(size: 10, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(t.fuelBurnTotal.round().toString(), style: fmMono(size: 24)),
          const SizedBox(height: 6),
          Text('KG/HR', style: fmLabel(size: 10, weight: FontWeight.w700, letterSpacing: 0)),
          const SizedBox(height: 10),
          Text('EST. AIRTIME $airtime', style: fmLabel(size: 10, color: fmAccent, weight: FontWeight.w800, letterSpacing: 0)),
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
    final hasTouchdown = t.isLanding;
    final vs = hasTouchdown ? t.touchdownVS.round() : null;
    final border = vs != null && vs < -600 ? fmRedDeep : fmBorder;
    final color = vs == null ? fmTextPrimary : (vs < -600 ? fmRed : (vs < -400 ? fmAmber : fmTextPrimary));

    return Container(
      decoration: fmCardDecoration(border: border),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('LANDING TOUCHDOWN', style: fmLabel(size: 10, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(vs?.toString() ?? '—', style: fmMono(size: 24, color: color)),
          const SizedBox(height: 6),
          Text('FPM', style: fmLabel(size: 10, weight: FontWeight.w700, letterSpacing: 0)),
          const SizedBox(height: 10),
          Text(
            hasTouchdown ? 'PITCH ${t.touchdownPitch.toStringAsFixed(1)}° · ${t.touchdownGForce.toStringAsFixed(2)}G' : '—',
            style: fmLabel(size: 9, weight: FontWeight.w700, letterSpacing: 0),
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
    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('G-FORCE', style: fmLabel(size: 10, letterSpacing: 1.2)),
          const SizedBox(height: 10),
          Text(t.gForce.toStringAsFixed(2), style: fmMono(size: 24)),
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
    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ENGINES / REHEAT', style: fmLabel()),
          const SizedBox(height: 14),
          Row(
            children: List.generate(4, (i) {
              final on = i < t.reheatActive.length && t.reheatActive[i];
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 3 ? 10 : 0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: on ? fmAmberBg : const Color(0xFF0F1520),
                      border: Border.all(color: on ? fmAmberDeep : fmBorder),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    child: Column(
                      children: [
                        Text('ENG ${i + 1}', style: fmLabel(size: 10, weight: FontWeight.w800, letterSpacing: 0)),
                        const SizedBox(height: 6),
                        Text(on ? 'REHEAT' : 'DRY', style: fmMono(size: 13, color: on ? fmAmber : fmTextSecondary)),
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
    // gearPosition streams as an extension percent 0-100; treat 0 as up,
    // 100 as down, anything between as in transit.
    final gearLabel = t.gearPosition <= 0.5 ? 'UP' : (t.gearPosition >= 99.5 ? 'DOWN' : 'TRANSIT');
    final gearColor = gearLabel == 'DOWN' ? fmGreen : (gearLabel == 'UP' ? fmTextSecondary : fmAmber);
    final flapsLabel = t.flapsPosition == 0 ? 'UP' : t.flapsPosition.toString();

    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('GEAR · FLAPS · DROOP NOSE · VISOR', style: fmLabel()),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _stat('GEAR', gearLabel, gearColor)),
              Expanded(child: _stat('FLAPS', flapsLabel, fmTextPrimary)),
              // The bridge streams a single nose-actuator simvar (visor)
              // and has no separate droop-nose reading, so both cells
              // reflect the same live value.
              Expanded(child: _stat('DROOP', '${t.snootAngle.round()}°', fmTextPrimary)),
              Expanded(child: _stat('VISOR/SNOOT', '${t.snootAngle.round()}°', fmTextPrimary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: fmLabel(size: 10, weight: FontWeight.w800, letterSpacing: 0)),
        const SizedBox(height: 6),
        Text(value, style: fmMono(size: 14, color: color)),
      ],
    );
  }
}
