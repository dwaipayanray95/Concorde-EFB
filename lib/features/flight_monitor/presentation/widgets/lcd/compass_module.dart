import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';
import 'lcd_painters.dart';

/// 04 // COMPASS
class CompassModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const CompassModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    final hdg = isConnected ? t.heading : 0.0;

    return LcdModulePanel(
      title: '04 // HEADING & COMPASS',
      tag: 'GPS',
      tagColor: lcdAmber,
      child: Column(
        children: [
          // Compass tape
          Container(
            height: 52,
            decoration: BoxDecoration(
              color: lcdCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: lcdBorder),
            ),
            clipBehavior: Clip.hardEdge,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: CompassTapePainter(heading: hdg)),
                // Center index
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(width: 1.5, height: 10, color: lcdRed),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: lcdBigCell('HDG', '${hdg.round().toString().padLeft(3, '0')}°', Colors.white),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: lcdBigCell('TRK', '${t.gs > 5 ? ((hdg + t.roll * 0.1) % 360).round().toString().padLeft(3, '0') : '---'}°', lcdAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(child: lcdInfoCell('LATITUDE', _fmtDeg(t.latitude, 'N', 'S'))),
              const SizedBox(width: 6),
              Expanded(child: lcdInfoCell('LONGITUDE', _fmtDeg(t.longitude, 'E', 'W'))),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDeg(double val, String pos, String neg) {
    final d = val.abs();
    final deg = d.floor();
    final min = ((d - deg) * 60).toStringAsFixed(2);
    return '${val >= 0 ? pos : neg}$deg° $min\'';
  }
}
