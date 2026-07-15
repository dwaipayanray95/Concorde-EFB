import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';

/// 03 // ALTIMETER + VSI
class AltimeterModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const AltimeterModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final alt = isConnected ? t.altitude : 0.0;
    final vs = isConnected ? t.vs : 0.0;
    final fl = (alt / 100).round();

    final int base = (alt / 500).floor() * 500;
    final ticks = List.generate(7, (i) => base - 1500 + i * 500);

    return LcdModulePanel(
      title: '03 // ALTIMETER & VSI',
      tag: 'BARO SYNC',
      tagColor: Colors.greenAccent,
      child: Column(
        children: [
          // Tape row
          Row(
            children: [
              // Altitude tape
              Expanded(
                flex: 3,
                child: Container(
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
                      ...ticks.where((v) => v >= 0).map((v) {
                        final dy = (alt - v) * 0.048;
                        return Positioned(
                          right: 0,
                          left: 0,
                          top: 0,
                          child: Transform.translate(
                            offset: Offset(0, -dy + 88),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('${v ~/ 100}', style: lcdMono(size: 8, color: lcdMuted)),
                                Container(width: 10, height: 1, color: lcdBorder),
                              ],
                            ),
                          ),
                        );
                      }),
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: lcdCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: lcdGreen, width: 2),
                            boxShadow: [
                              BoxShadow(color: lcdGreen.withValues(alpha: 0.35), blurRadius: 16),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('ALT FT', style: lcdLabel(size: 8, color: lcdGreen)),
                              Text(
                                alt.round().toString().replaceAllMapped(
                                  RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
                                  (m) => '${m[1]},',
                                ),
                                style: lcdMono(size: 18, color: Colors.white),
                              ),
                              Text('FL${fl.toString().padLeft(3, '0')}', style: lcdMono(size: 10, color: lcdGreen)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // VSI
              Container(
                width: 48,
                height: 200,
                decoration: BoxDecoration(
                  color: lcdCard,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lcdBorder),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('VSI', style: lcdLabel(size: 7)),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Center(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: _VsiBar(vs: vs),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${vs >= 0 ? '+' : ''}${vs.round()}',
                      style: lcdMono(size: 8, color: vs >= 0 ? Colors.greenAccent : lcdRed),
                    ),
                    Text('ft/m', style: lcdLabel(size: 7)),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VsiBar extends StatelessWidget {
  final double vs;
  const _VsiBar({required this.vs});

  @override
  Widget build(BuildContext context) {
    final frac = (vs.abs() / 2500.0).clamp(0.0, 1.0);
    return Container(
      width: double.infinity,
      height: 8,
      decoration: BoxDecoration(
        color: lcdBorder,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Align(
        alignment: vs >= 0 ? Alignment.centerLeft : Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: frac,
          child: Container(
            decoration: BoxDecoration(
              color: vs >= 0 ? Colors.greenAccent : lcdRed,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}
