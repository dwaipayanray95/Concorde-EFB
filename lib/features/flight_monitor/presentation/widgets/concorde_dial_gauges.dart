import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ui_tokens.dart';

class ConcordeAirspeedGauge extends StatelessWidget {
  final double ias;
  final double mach;

  const ConcordeAirspeedGauge({super.key, required this.ias, required this.mach});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _AirspeedGaugePainter(ias: ias),
          ),
          Positioned(
            bottom: 36,
            child: Column(
              children: [
                Text(
                  'IAS KTS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white30,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  ias.round().toString(),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: UiTokens.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 36,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black38,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'M ${mach.toStringAsFixed(2)}',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: mach >= 1.0 ? Colors.orangeAccent : UiTokens.accent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AirspeedGaugePainter extends CustomPainter {
  final double ias;

  _AirspeedGaugePainter({required this.ias});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Draw ticks
    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    // Airspeed from 0 to 500 knots. Let's map it from -140 deg to +140 deg.
    const startAngle = -140 * math.pi / 180;
    const endAngle = 140 * math.pi / 180;
    const totalAngle = endAngle - startAngle;

    for (int kts = 0; kts <= 500; kts += 50) {
      final pct = kts / 500.0;
      final angle = startAngle + (totalAngle * pct);

      final isMajor = kts % 100 == 0;
      final tickLength = isMajor ? 8.0 : 4.0;
      
      final tickStart = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(tickStart, tickEnd, paint..color = isMajor ? Colors.white38 : Colors.white24);

      if (isMajor && kts > 0 && kts < 500) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: kts.toString(),
            style: GoogleFonts.plusJakartaSans(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.white54,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        final labelRadius = radius - 18;
        final labelX = center.dx + labelRadius * math.cos(angle) - textPainter.width / 2;
        final labelY = center.dy + labelRadius * math.sin(angle) - textPainter.height / 2;
        textPainter.paint(canvas, Offset(labelX, labelY));
      }
    }

    // Draw needle
    final needleAngle = startAngle + (totalAngle * (ias.clamp(0.0, 500.0) / 500.0));
    final needlePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + (radius - 12) * math.cos(needleAngle),
      center.dy + (radius - 12) * math.sin(needleAngle),
    );
    canvas.drawLine(center, needleEnd, needlePaint);

    // Center cap
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AirspeedGaugePainter oldDelegate) => oldDelegate.ias != ias;
}

class ConcordeAltimeterGauge extends StatelessWidget {
  final double altitude;

  const ConcordeAltimeterGauge({super.key, required this.altitude});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _AltimeterGaugePainter(altitude: altitude),
          ),
          Positioned(
            bottom: 36,
            child: Column(
              children: [
                Text(
                  'ALTITUDE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white30,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white12, width: 1),
                  ),
                  child: Text(
                    altitude.round().toString().padLeft(5, '0'),
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                      letterSpacing: 0.5,
                    ),
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

class _AltimeterGaugePainter extends CustomPainter {
  final double altitude;

  _AltimeterGaugePainter({required this.altitude});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    // Draw ticks from 0 to 9 (10 divisions representing 1000 ft total per rotation)
    for (int tick = 0; tick < 10; tick++) {
      final angle = (tick * 36 - 90) * math.pi / 180;
      final tickLength = 8.0;
      
      final tickStart = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(tickStart, tickEnd, paint);

      // Label tick
      final textPainter = TextPainter(
        text: TextSpan(
          text: tick.toString(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRadius = radius - 18;
      final labelX = center.dx + labelRadius * math.cos(angle) - textPainter.width / 2;
      final labelY = center.dy + labelRadius * math.sin(angle) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(labelX, labelY));
    }

    // Needle rotates once per 1000 feet
    final feetOnDial = altitude % 1000.0;
    final needleAngle = (feetOnDial * 0.36 - 90) * math.pi / 180;
    
    final needlePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + (radius - 15) * math.cos(needleAngle),
      center.dy + (radius - 15) * math.sin(needleAngle),
    );
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _AltimeterGaugePainter oldDelegate) => oldDelegate.altitude != altitude;
}

class ConcordeVerticalSpeedGauge extends StatelessWidget {
  final double vs;

  const ConcordeVerticalSpeedGauge({super.key, required this.vs});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      height: 150,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10, width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(140, 140),
            painter: _VSGaugePainter(vs: vs),
          ),
          Positioned(
            bottom: 36,
            child: Column(
              children: [
                Text(
                  'V/S FPM',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                    color: Colors.white30,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${vs > 0 ? '+' : ''}${vs.round()}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: vs.abs() > 2000 ? Colors.amberAccent : UiTokens.textPrimary,
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

class _VSGaugePainter extends CustomPainter {
  final double vs;

  _VSGaugePainter({required this.vs});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final paint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.5;

    // VS ranges from -6000 to +6000 FPM.
    // 0 is pointing horizontal left (180 degrees).
    // Climb (+6000) goes up to -45 deg. Descent (-6000) goes down to +45 deg.
    const startAngle = 180.0 * math.pi / 180.0;

    final Map<int, double> angleMap = {
      -6: 60 * math.pi / 180.0,
      -4: 95 * math.pi / 180.0,
      -2: 130 * math.pi / 180.0,
      -1: 155 * math.pi / 180.0,
      0: 180 * math.pi / 180.0,
      1: 205 * math.pi / 180.0,
      2: 230 * math.pi / 180.0,
      4: 265 * math.pi / 180.0,
      6: 300 * math.pi / 180.0,
    };

    angleMap.forEach((fpm, angle) {
      final tickLength = 8.0;
      final tickStart = Offset(
        center.dx + (radius - tickLength) * math.cos(angle),
        center.dy + (radius - tickLength) * math.sin(angle),
      );
      final tickEnd = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(tickStart, tickEnd, paint..color = fpm == 0 ? Colors.redAccent : Colors.white38);

      // Draw label
      final textPainter = TextPainter(
        text: TextSpan(
          text: fpm.abs().toString(),
          style: GoogleFonts.plusJakartaSans(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: fpm == 0 ? Colors.redAccent : Colors.white54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelRadius = radius - 18;
      final labelX = center.dx + labelRadius * math.cos(angle) - textPainter.width / 2;
      final labelY = center.dy + labelRadius * math.sin(angle) - textPainter.height / 2;
      textPainter.paint(canvas, Offset(labelX, labelY));
    });

    // Interpolate pointer angle
    double needleAngle = startAngle;
    final vsThousands = vs / 1000.0;
    
    if (vsThousands <= -6.0) {
      needleAngle = angleMap[-6]!;
    } else if (vsThousands >= 6.0) {
      needleAngle = angleMap[6]!;
    } else {
      // Find bounding keys
      final sortedKeys = angleMap.keys.toList()..sort();
      for (int i = 0; i < sortedKeys.length - 1; i++) {
        final k1 = sortedKeys[i];
        final k2 = sortedKeys[i+1];
        if (vsThousands >= k1 && vsThousands <= k2) {
          final a1 = angleMap[k1]!;
          final a2 = angleMap[k2]!;
          final ratio = (vsThousands - k1) / (k2 - k1);
          needleAngle = a1 + (a2 - a1) * ratio;
          break;
        }
      }
    }

    final needlePaint = Paint()
      ..color = Colors.orangeAccent
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final needleEnd = Offset(
      center.dx + (radius - 12) * math.cos(needleAngle),
      center.dy + (radius - 12) * math.sin(needleAngle),
    );
    canvas.drawLine(center, needleEnd, needlePaint);
    canvas.drawCircle(center, 4, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _VSGaugePainter oldDelegate) => oldDelegate.vs != vs;
}
