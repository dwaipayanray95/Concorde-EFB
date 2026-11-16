import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';

/// Lightweight vector altitude profile sparkline for logbook tiles.
class FlightSparkline extends StatelessWidget {
  final List<List<num>> track;
  final double width;
  final double height;
  final double? maxAltFt;

  const FlightSparkline({
    super.key,
    required this.track,
    this.width = 130,
    this.height = 32,
    this.maxAltFt,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return RepaintBoundary(
      child: SizedBox(
        width: width,
        height: height,
        child: CustomPaint(
          size: Size(width, height),
          painter: _SparklinePainter(
            track: track,
            colors: colors,
            forcedMaxAlt: maxAltFt,
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final List<List<num>> track;
  final AppColors colors;
  final double? forcedMaxAlt;

  _SparklinePainter({
    required this.track,
    required this.colors,
    this.forcedMaxAlt,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (track.length < 2) {
      _paintPlaceholder(canvas, size);
      return;
    }

    // Index 3 is altFt in FlightLog.track
    double peak = forcedMaxAlt ?? 0;
    if (peak <= 0) {
      for (final p in track) {
        if (p.length > 3) {
          final alt = p[3].toDouble();
          if (alt > peak) peak = alt;
        }
      }
    }
    // Concorde cruise is up to FL600
    peak = math.max(peak, 50000.0);

    final path = Path();
    final fillPath = Path();

    final step = math.max(1, (track.length / 100).floor());
    var first = true;
    double lastX = 0;

    for (var i = 0; i < track.length; i += step) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final x = (i / (track.length - 1)) * size.width;
      // Leave 2px margin top and bottom
      final normalizedAlt = (alt / peak).clamp(0.0, 1.0);
      final y = size.height - 2 - (normalizedAlt * (size.height - 4));

      if (first) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
      lastX = x;
    }

    // Ensure we reach the very end point
    if (track.isNotEmpty && (track.length - 1) % step != 0) {
      final p = track.last;
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final x = size.width;
      final normalizedAlt = (alt / peak).clamp(0.0, 1.0);
      final y = size.height - 2 - (normalizedAlt * (size.height - 4));
      path.lineTo(x, y);
      fillPath.lineTo(x, y);
      lastX = x;
    }

    fillPath.lineTo(lastX, size.height);
    fillPath.close();

    // Gradient fill under profile
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.accent.withValues(alpha: 0.30),
          colors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    // Profile line stroke
    final strokePaint = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);
  }

  void _paintPlaceholder(Canvas canvas, Size size) {
    final p = Paint()
      ..color = colors.dividerStrong.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const dashWidth = 4.0;
    const dashSpace = 4.0;
    var startX = 0.0;
    final y = size.height / 2;

    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, y),
        Offset(math.min(startX + dashWidth, size.width), y),
        p,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.track.length != track.length ||
        oldDelegate.colors != colors ||
        oldDelegate.forcedMaxAlt != forcedMaxAlt;
  }
}
