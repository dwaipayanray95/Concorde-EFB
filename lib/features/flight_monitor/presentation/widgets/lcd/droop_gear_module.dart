import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';
import 'lcd_painters.dart';

/// 08 // CONCORDE DROOP, GEAR & GEOMETRY
class ConcordeDroopGearModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const ConcordeDroopGearModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final snoot = isConnected ? t.snootAngle : 0.0;
    final gearPct = isConnected ? t.gearPosition : 0.0;
    final gearDown = gearPct > 0.8;
    final gearInTransit = gearPct > 0.05 && gearPct < 0.95;

    return LcdModulePanel(
      title: '08 // DROOP NOSE & GEAR',
      tag: 'CONCORDE',
      tagColor: Colors.purpleAccent,
      child: Column(
        children: [
          // Nose droop visual
          Container(
            height: 80,
            decoration: BoxDecoration(
              color: lcdCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: lcdBorder),
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                // Animated droop indicator
                CustomPaint(
                  size: const Size(120, 60),
                  painter: DroopNosePainter(angle: snoot),
                ),
                const Spacer(),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('NOSE DROOP', style: lcdLabel(size: 8)),
                    Text(
                      '${snoot.toStringAsFixed(1)}°',
                      style: lcdMono(size: 22, color: snoot > 0 ? lcdAmber : lcdAccent),
                    ),
                    Text(
                      snoot >= 12.5 ? 'FULLY DOWN' : snoot >= 5.0 ? 'PARTIAL' : 'RETRACTED',
                      style: lcdMono(size: 9, color: snoot > 0 ? lcdAmber : lcdMuted),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Gear status
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: gearDown
                        ? Colors.greenAccent.withValues(alpha: 0.08)
                        : gearInTransit
                            ? lcdAmber.withValues(alpha: 0.08)
                            : lcdBg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: gearDown
                          ? Colors.greenAccent.withValues(alpha: 0.3)
                          : gearInTransit
                              ? lcdAmber.withValues(alpha: 0.3)
                              : lcdBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('LANDING GEAR', style: lcdLabel(size: 9)),
                      Text(
                        gearDown ? '▼ DOWN' : gearInTransit ? '⟳ TRANSIT' : '▲ UP',
                        style: lcdMono(
                          size: 11,
                          color: gearDown
                              ? Colors.greenAccent
                              : gearInTransit
                                  ? lcdAmber
                                  : Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: lcdInfoCell('FLAPS', 'POS ${t.flapsPosition}')),
              const SizedBox(width: 6),
              Expanded(child: lcdInfoCell('G FORCE', '${t.gForce.toStringAsFixed(2)} G', t.gForce > 1.5 ? lcdAmber : lcdAccent)),
            ],
          ),
        ],
      ),
    );
  }
}
