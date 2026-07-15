import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';
import 'lcd_painters.dart';

/// 02 // AIRSPEED
class AirspeedModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const AirspeedModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final ias = isConnected ? t.ias : 0.0;
    final mach = isConnected ? t.mach : 0.0;

    const redlineKts = 380.0;
    const stallKts = 150.0;

    // Build tape ticks
    final int base = (ias / 20).floor() * 20;
    final ticks = List.generate(9, (i) => base - 80 + i * 20);

    return LcdModulePanel(
      title: '02 // AIRSPEED PERFORMANCE',
      tag: 'VNE WARNINGS',
      child: Column(
        children: [
          // Tape
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: lcdCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: lcdBorder),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Left caution stripe
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 4,
                  child: cautionStripe(),
                ),

                // Scrolling ticks
                ...ticks.where((v) => v >= 0).map((v) {
                  final dy = (ias - v) * 1.6;
                  final isStall = v <= stallKts;
                  final isOver = v >= redlineKts;
                  return Positioned(
                    right: 0,
                    top: 0,
                    left: 6,
                    child: Transform.translate(
                      offset: Offset(0, -dy + 88),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '$v',
                            style: lcdMono(
                              size: 9,
                              color: isStall ? lcdRed : isOver ? Colors.orangeAccent : lcdMuted,
                            ),
                          ),
                          Container(
                            width: 12,
                            height: 1.5,
                            color: isStall ? lcdRed : isOver ? Colors.orangeAccent : lcdBorder,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                // Central readout
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: lcdCard,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: lcdAccent, width: 2),
                      boxShadow: [
                        BoxShadow(color: lcdAccentGlow, blurRadius: 16),
                        BoxShadow(color: lcdAccent.withValues(alpha: 0.15), blurRadius: 40),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('IAS', style: lcdLabel(size: 9, color: lcdAccent)),
                        Text(
                          ias.round().toString(),
                          style: lcdMono(size: 32, color: Colors.white),
                        ),
                        Text('KTS', style: lcdLabel(size: 9)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: lcdInfoCell(
                  'MACH',
                  'M ${mach.toStringAsFixed(3)}',
                  mach >= 1.0 ? Colors.orangeAccent : Colors.white70,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: lcdInfoCell(
                  'TREND',
                  ias > 380 ? '▼ DECEL' : ias > 300 ? '▲ ACCEL' : '■ STABLE',
                  ias > 380 ? lcdRed : lcdAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
