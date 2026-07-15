import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';
import 'lcd_painters.dart';

/// 01 // PFD — Attitude Horizon
class PfdModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const PfdModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final pitch = isConnected ? t.pitch : 0.0;
    final roll = isConnected ? t.roll : 0.0;

    return LcdModulePanel(
      title: '01 // ATTITUDE HORIZON',
      tag: 'LIVE',
      child: Column(
        children: [
          // Horizon box
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: lcdCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: lcdBorder, width: 1.5),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Rolling horizon
                Center(
                  child: Transform.rotate(
                    angle: roll * 3.14159 / 180.0,
                    child: Transform.translate(
                      offset: Offset(0, pitch * 3.5),
                      child: SizedBox(
                        width: 600,
                        height: 600,
                        child: Column(
                          children: [
                            Expanded(
                              child: Container(
                                color: lcdSky,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: _pitchLines(isSky: true),
                                ),
                              ),
                            ),
                            Container(height: 1.5, color: Colors.white),
                            Expanded(
                              child: Container(
                                color: lcdGround,
                                child: Align(
                                  alignment: Alignment.topCenter,
                                  child: _pitchLines(isSky: false),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                // Aircraft reference
                Center(
                  child: CustomPaint(
                    size: const Size(100, 30),
                    painter: AircraftPainter(),
                  ),
                ),

                // Roll/Pitch corner readouts
                Positioned(
                  bottom: 6,
                  left: 8,
                  child: _cornerBadge('ROLL', '${roll.toStringAsFixed(1)}°', roll.abs() > 30 ? lcdAmber : Colors.white70),
                ),
                Positioned(
                  bottom: 6,
                  right: 8,
                  child: _cornerBadge('PITCH', '${pitch.toStringAsFixed(1)}°', pitch.abs() > 15 ? lcdAmber : Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // G-Force row
          Row(
            children: [
              Expanded(child: _dataCell('G-FORCE', '${t.gForce.toStringAsFixed(2)} G', t.gForce > 2.0 ? lcdAmber : lcdAccent)),
              const SizedBox(width: 6),
              Expanded(child: _dataCell('GND SPD', '${t.gs.round()} KTS')),
              const SizedBox(width: 6),
              Expanded(child: _dataCell('TAS', '${t.tas.round()} KTS')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pitchLines({required bool isSky}) {
    return SizedBox(
      height: 80,
      child: Column(
        mainAxisAlignment: isSky ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [10, 20].map((deg) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: isSky ? 4 : 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('${isSky ? '' : '-'}$deg', style: lcdMono(size: 7, color: Colors.white24)),
                Container(width: 30, height: 1, color: Colors.white24),
                const SizedBox(width: 4),
                Container(width: 30, height: 1, color: Colors.white24),
                Text('${isSky ? '' : '-'}$deg', style: lcdMono(size: 7, color: Colors.white24)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _cornerBadge(String label, String val, Color valColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: lcdBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ', style: lcdMono(size: 9, color: lcdLabelColor, weight: FontWeight.normal)),
          Text(val, style: lcdMono(size: 9, color: valColor)),
        ],
      ),
    );
  }

  Widget _dataCell(String label, String val, [Color valColor = Colors.white]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: lcdCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: lcdBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: lcdLabel(size: 9)),
          const SizedBox(height: 3),
          Text(val, style: lcdMono(size: 13, color: valColor)),
        ],
      ),
    );
  }
}
