import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WindArrow extends StatelessWidget {
  final double? runwayHeading;
  final double? windDir;
  final double? windSpeedKt;
  final double size;
  final Color color;

  const WindArrow({
    super.key,
    required this.runwayHeading,
    required this.windDir,
    this.windSpeedKt,
    this.size = 24.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (runwayHeading == null || windDir == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'VRB',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Calculate wind direction relative to the runway.
    // windDir is where the wind is coming FROM.
    // runwayHeading is where the nose of the plane points.
    final relWind = ((windDir! - runwayHeading!) % 360 + 360) % 360;
    
    // We want the runway graphic to always be straight UP (vertical).
    // The runway graphic is drawn vertically by default, so rotation is 0.
    final runwayRadians = 0.0;
    
    // The arrow icon points UP by default.
    // If we have a direct headwind (relWind = 0), the wind is coming FROM straight ahead,
    // meaning the arrow should point DOWN (180 degrees) towards the bottom of the runway.
    final arrowRotation = (relWind + 180) % 360;
    final arrowRadians = arrowRotation * math.pi / 180;

    Color arrowColor = color;
    if (windSpeedKt != null) {
      if (windSpeedKt! < 6) {
        arrowColor = const Color(0xFF10B981); // Green
      } else if (windSpeedKt! < 16) {
        arrowColor = const Color(0xFF3B82F6); // Blue
      } else if (windSpeedKt! < 26) {
        arrowColor = const Color(0xFFF59E0B); // Yellow
      } else {
        arrowColor = const Color(0xFFEF4444); // Red
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Runway Indicator Graphic (Longer/Thicker for visibility)
          Transform.rotate(
            angle: runwayRadians,
            child: Container(
              width: size * 0.18,
              height: size * 0.95,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => Container(
                  width: 2,
                  height: size * 0.12,
                  color: Colors.white.withValues(alpha: 0.8),
                )),
              ),
            ),
          ),
          // Wind Arrow Indicator (Custom Painted with a longer, thicker tail for legibility)
          Transform.rotate(
            angle: arrowRadians,
            child: CustomPaint(
              size: Size(size * 0.8, size * 0.8),
              painter: _ArrowPainter(color: arrowColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  const _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double startY = size.height * 0.85; // Arrow tail start
    final double endY = size.height * 0.15;   // Arrow head tip
    final double centerX = size.width / 2;
    final double headSize = size.width * 0.28;

    // 1. Draw a dark "masking outline" (halo) using the background color
    // to clear the runway dashes underneath the arrow.
    final maskPaint = Paint()
      ..color = const Color(0xFF090D16) // Matches the new deep space background color
      ..strokeWidth = size.width * 0.22 // Thicker stroke to create the border gap
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw mask tail
    canvas.drawLine(
      Offset(centerX, startY),
      Offset(centerX, endY),
      maskPaint,
    );

    // Draw mask head barbs
    canvas.drawLine(
      Offset(centerX, endY),
      Offset(centerX - headSize, endY + headSize),
      maskPaint,
    );
    canvas.drawLine(
      Offset(centerX, endY),
      Offset(centerX + headSize, endY + headSize),
      maskPaint,
    );

    // 2. Draw the actual colored arrow on top
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.10 // Thicker, visible tail stroke
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Draw the long vertical tail
    canvas.drawLine(
      Offset(centerX, startY),
      Offset(centerX, endY),
      paint,
    );

    // Draw the arrow head
    canvas.drawLine(
      Offset(centerX, endY),
      Offset(centerX - headSize, endY + headSize),
      paint,
    );
    canvas.drawLine(
      Offset(centerX, endY),
      Offset(centerX + headSize, endY + headSize),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) => oldDelegate.color != color;
}
