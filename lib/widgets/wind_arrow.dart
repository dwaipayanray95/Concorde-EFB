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

  /// Runway identifier (e.g. "09L") shown under the strip so the runway
  /// this indicator refers to is obvious at a glance, without having to
  /// cross-reference the ICAO/runway fields above it.
  final String? runwayLabel;

  const WindArrow({
    super.key,
    required this.runwayHeading,
    required this.windDir,
    this.windSpeedKt,
    this.size = 24.0,
    this.color,
    this.runwayLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    if (runwayHeading == null || windDir == null) {
      return SizedBox(
        width: size,
        height: size,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'VRB',
              style: uiText(
                context,
                size: 10,
                weight: FontWeight.bold,
                color: colors.textSecondary,
              ),
            ),
            if (runwayLabel != null && runwayLabel!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                runwayLabel!,
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w800,
                  color: colors.textDim,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ],
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

    final hasLabel = runwayLabel != null && runwayLabel!.isNotEmpty;
    final labelHeight = hasLabel ? size * 0.14 : 0.0;
    final stripSize = size - labelHeight;

    return SizedBox(
      width: size,
      height: size,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: size,
            height: stripSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.rotate(
                  angle: runwayRadians,
                  child: CustomPaint(
                    size: Size(stripSize * 0.22, stripSize * 1.08),
                    painter: _RunwayPainter(
                      pavementColor: colors.dividerStrong.withValues(
                        alpha: 0.55,
                      ),
                      markingColor: colors.textDim.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                Transform.rotate(
                  angle: arrowRadians,
                  child: CustomPaint(
                    size: Size(stripSize * 0.8, stripSize * 0.8),
                    painter: _ArrowPainter(color: arrowColor),
                  ),
                ),
              ],
            ),
          ),
          if (hasLabel) ...[
            const SizedBox(height: 4),
            Text(
              runwayLabel!,
              style: uiText(
                context,
                size: 10,
                weight: FontWeight.w800,
                color: colors.textDim,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Draws a runway strip in one self-contained paint pass: pavement fill plus
/// a dashed centerline. Kept as a CustomPainter (rather than a Container +
/// Column of tick widgets) so this look can't be quietly stripped down to a
/// plain line/border by an unrelated future edit -- everything that makes it
/// read as "runway" lives in this one paint() call.
class _RunwayPainter extends CustomPainter {
  final Color pavementColor;
  final Color markingColor;

  const _RunwayPainter({
    required this.pavementColor,
    required this.markingColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pavementRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(size.width * 0.3),
    );
    canvas.drawRRect(pavementRect, Paint()..color = pavementColor);

    final dashPaint = Paint()..color = markingColor;
    final dashWidth = size.width * 0.16;
    final dashHeight = size.height * 0.06;
    final dashGap = dashHeight * 1.4;
    final centerX = size.width / 2;

    var y = dashHeight / 2;
    while (y < size.height) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(centerX, y),
            width: dashWidth,
            height: dashHeight,
          ),
          Radius.circular(dashWidth * 0.3),
        ),
        dashPaint,
      );
      y += dashHeight + dashGap;
    }
  }

  @override
  bool shouldRepaint(covariant _RunwayPainter oldDelegate) =>
      oldDelegate.pavementColor != pavementColor ||
      oldDelegate.markingColor != markingColor;
}

class _ArrowPainter extends CustomPainter {
  final Color color;

  const _ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double startY = size.height * 0.85;
    final double endY = size.height * 0.15;
    final double centerX = size.width / 2;
    final double headSize = size.width * 0.28;

    final paint = Paint()
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
      oldDelegate.color != color;
}
