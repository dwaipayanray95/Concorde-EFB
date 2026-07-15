import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';

/// 05 // EICAS — 4× Olympus 593 Engines
class EicasModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const EicasModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final n1 = isConnected ? ((t.ias / 4.5) + 62.0).clamp(0.0, 100.0) : 0.0;
    final egt = isConnected ? (520.0 + n1 * 1.5) : 0.0;
    final totalFlow = isConnected ? t.fuelBurnTotal : 0.0;

    return LcdModulePanel(
      title: '05 // ENGINE TELEMETRY (EICAS)',
      tag: 'OLYMPUS 593',
      tagColor: Colors.greenAccent,
      child: Column(
        children: [
          // 4 engine blocks side by side
          Row(
            children: List.generate(4, (i) {
              final reheat = isConnected && t.reheatActive.length > i && t.reheatActive[i];
              // Slight engine-to-engine variation
              final engineN1 = n1 + (i.isOdd ? 0.3 : -0.2);
              final engineEgt = egt + (i.isOdd ? 3.0 : -2.0);

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: lcdCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: reheat
                          ? Colors.orangeAccent.withValues(alpha: 0.4)
                          : lcdBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text('ENG ${i + 1}', style: lcdLabel(size: 9)),
                      const SizedBox(height: 8),

                      // N1 bar
                      _engineBar('N1', engineN1, 100.0, engineN1 > 90 ? lcdAmber : Colors.greenAccent),
                      const SizedBox(height: 6),

                      // EGT bar
                      _engineBar('EGT', engineEgt, 900.0, engineEgt > 750 ? lcdRed : engineEgt > 680 ? lcdAmber : lcdAccent),
                      const SizedBox(height: 10),

                      // Reheat dot
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 5,
                            height: 5,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: reheat ? Colors.orangeAccent : lcdBorder,
                              boxShadow: reheat
                                  ? [const BoxShadow(color: Colors.orangeAccent, blurRadius: 6)]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text('REHEAT', style: lcdMono(size: 7, color: reheat ? Colors.orangeAccent : lcdMuted)),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),

          // Total flow + EGT readout
          Row(
            children: [
              Expanded(
                child: lcdInfoCell(
                  'TOTAL FUEL FLOW',
                  '${totalFlow.round()} KG/HR',
                  lcdAccent,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: lcdInfoCell(
                  'CORE EGT AVG',
                  '${egt.round()} °C',
                  egt > 750 ? lcdRed : Colors.white70,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _engineBar(String label, double val, double max, Color barColor) {
    final frac = (val / max).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: lcdLabel(size: 7)),
            Text(
              val > 100 ? '${val.round()}°' : '${val.toStringAsFixed(1)}%',
              style: lcdMono(size: 8, color: barColor),
            ),
          ],
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: frac,
            backgroundColor: lcdBorder,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}
