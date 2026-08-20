import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';

class WindArrow extends StatelessWidget {
  final double? runwayHeading;
  final double? windDir;
  final double? windSpeedKt;
  final double size;
  final Color? color;

  const WindArrow({
    super.key,
    required this.runwayHeading,
    required this.windDir,
    this.windSpeedKt,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (runwayHeading == null || windDir == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Center(
          child: Text(
            'VRB',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.bold,
              color: colors.textSecondary,
            ),
          ),
        ),
      );
    }

    final relWind = ((windDir! - runwayHeading!) % 360 + 360) % 360;
    const runwayRadians = 0.0;
    final arrowRotation = (relWind + 180) % 360;
    final arrowRadians = arrowRotation * math.pi / 180;

    Color arrowColor = color ?? colors.arrival;
    if (windSpeedKt != null) {
      if (windSpeedKt! < 6) {
        arrowColor = colors.arrival;
      } else if (windSpeedKt! < 16) {
        arrowColor = colors.accent;
      } else if (windSpeedKt! < 26) {
        arrowColor = colors.mvfr;
      } else {
        arrowColor = colors.error;
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: runwayRadians,
            child: Container(
              width: size * 0.16,
              height: size * 1.08,
              decoration: BoxDecoration(
                color: colors.dividerStrong.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(
                  5,
                  (index) => Container(
                    width: 2,
                    height: size * 0.10,
                    color: colors.textDim.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: arrowRadians,
            child: CustomPaint(
              size: Size(size * 0.8, size * 0.8),
              painter: _ArrowPainter(
                color: arrowColor,
                maskColor: colors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrowPainter extends CustomPainter {
  final Color color;
  final Color maskColor;

  const _ArrowPainter({required this.color, required this.maskColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double startY = size.height * 0.85;
    final double endY = size.height * 0.15;
    final double centerX = size.width / 2;
    final double headSize = size.width * 0.28;

    final maskPaint =
        Paint()
          ..color = maskColor
          ..strokeWidth = size.width * 0.22
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), maskPaint);
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

    final paint =
        Paint()
          ..color = color
          ..strokeWidth = size.width * 0.10
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(centerX, startY), Offset(centerX, endY), paint);
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
  bool shouldRepaint(covariant _ArrowPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.maskColor != maskColor;
}
