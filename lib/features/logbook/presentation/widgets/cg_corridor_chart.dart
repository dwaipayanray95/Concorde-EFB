import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/ui_text.dart';
import '../../data/flight_log.dart';

/// Concorde CG vs Mach Aerodynamic Flight Envelope Corridor Chart.
/// Plots the flight's actual CG trimming trajectory against the DC Designs
/// certified forward and aft CG limits.
class CgCorridorChart extends StatelessWidget {
  final FlightLog log;

  const CgCorridorChart({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = log.track;

    if (track.isEmpty) {
      return const SizedBox();
    }

    // Compute key phase CG metrics
    double? subsonicCg;
    double? cruiseCg;
    double? appCg;
    var safeCorridor = true;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final m = p.length > 7 ? p[7].toDouble() : 0.0;
      final cg = p.length > 9 ? p[9].toDouble() : 0.0;

      if (cg <= 0) continue;

      if (subsonicCg == null && alt > 5000 && m < 0.90) {
        subsonicCg = cg;
      }
      if (cruiseCg == null && m >= 1.95 && alt >= 50000) {
        cruiseCg = cg;
      }
      if (i > track.length * 0.9 && alt < 5000) {
        appCg = cg;
      }

      // Check boundary exceedance
      if (m <= 0.90 && (cg < 51.8 || cg > 55.0)) safeCorridor = false;
      if (m >= 1.95 && (cg < 57.0 || cg > 59.3)) safeCorridor = false;
    }

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'CONCORDE CG FLIGHT ENVELOPE (MACH vs CG %)',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w900,
                      color: colors.accent,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: (safeCorridor ? colors.success : colors.error)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: (safeCorridor ? colors.success : colors.error)
                        .withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  safeCorridor ? '100% IN SAFE CORRIDOR' : 'CG WARNING RECORDED',
                  style: uiText(
                    context,
                    size: 8,
                    weight: FontWeight.w900,
                    color: safeCorridor ? colors.success : colors.error,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'DC Designs limits: 52.0% fwd limit, 59.0% aft limit. Pilot trims fuel aft during transonic climb and forward for descent.',
            style: uiText(context, size: 10, color: colors.textSecondary),
          ),
          const SizedBox(height: 12),

          // The CG Corridor Canvas
          LayoutBuilder(
            builder: (context, c) {
              return SizedBox(
                width: c.maxWidth,
                height: 180,
                child: CustomPaint(
                  size: Size(c.maxWidth, 180),
                  painter: _CgCorridorPainter(track: track, colors: colors),
                ),
              );
            },
          ),
          const SizedBox(height: 12),

          // 3 Phase CG Stat Blocks
          Row(
            children: [
              Expanded(
                child: _cgStatTile(
                  context,
                  'SUBSONIC CG',
                  subsonicCg != null ? '${subsonicCg.toStringAsFixed(1)}%' : '--',
                  'LIMIT 52.0 - 54.5%',
                  colors,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cgStatTile(
                  context,
                  'M2.0 CRUISE CG',
                  cruiseCg != null ? '${cruiseCg.toStringAsFixed(1)}%' : '--',
                  'LIMIT 57.5 - 59.0%',
                  colors,
                  valColor: colors.accent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _cgStatTile(
                  context,
                  'APPROACH CG',
                  appCg != null ? '${appCg.toStringAsFixed(1)}%' : '--',
                  'LIMIT 53.0 - 55.0%',
                  colors,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cgStatTile(
    BuildContext context,
    String label,
    String val,
    String sub,
    AppColors colors, {
    Color? valColor,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: colors.resultsBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: uiText(
                context,
                size: 8,
                weight: FontWeight.w800,
                color: colors.textDim,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              val,
              style: uiText(
                context,
                size: 14,
                weight: FontWeight.w900,
                color: valColor ?? colors.textPrimary,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              sub,
              style: uiText(context, size: 8, color: colors.textDim),
            ),
          ],
        ),
      );
}

class _CgCorridorPainter extends CustomPainter {
  final List<List<num>> track;
  final AppColors colors;

  _CgCorridorPainter({required this.track, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 40.0;
    const padR = 24.0;
    const padT = 16.0;
    const padB = 22.0;

    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (plotW <= 0 || plotH <= 0) return;

    double toX(double m) => padL + (m / 2.2).clamp(0.0, 1.0) * plotW;
    double toY(double cg) =>
        padT + plotH * (1.0 - ((cg - 51.0) / (60.0 - 51.0)).clamp(0.0, 1.0));

    // Gridlines for CG: 52%, 54%, 56%, 58%, 60%
    final gridPaint = Paint()
      ..color = colors.dividerStrong.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var cg = 52.0; cg <= 60.0; cg += 2.0) {
      final y = toY(cg);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: '${cg.round()}%',
          style: TextStyle(
            color: colors.textDim,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(padL - tp.width - 6, y - tp.height / 2));
    }

    // Gridlines for Mach: 0.5, 1.0, 1.5, 2.0
    for (var m = 0.5; m <= 2.0; m += 0.5) {
      final x = toX(m);
      canvas.drawLine(Offset(x, padT), Offset(x, padT + plotH), gridPaint);

      final tp = TextPainter(
        text: TextSpan(
          text: 'M${m.toStringAsFixed(1)}',
          style: TextStyle(
            color: colors.textDim,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padT + plotH + 5));
    }

    // Certified Safe Flight Envelope Polygon (Green Tint)
    final poly = Path();
    poly.moveTo(toX(0.0), toY(54.5));
    poly.lineTo(toX(0.9), toY(55.0));
    poly.lineTo(toX(1.4), toY(58.0));
    poly.lineTo(toX(2.04), toY(59.1));
    poly.lineTo(toX(2.04), toY(57.5));
    poly.lineTo(toX(1.4), toY(55.0));
    poly.lineTo(toX(0.9), toY(52.0));
    poly.lineTo(toX(0.0), toY(52.0));
    poly.close();

    final fillPaint = Paint()
      ..color = colors.success.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;
    canvas.drawPath(poly, fillPaint);

    final borderPaint = Paint()
      ..color = colors.success.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawPath(poly, borderPaint);

    // Flown Flight Path Trajectory through Mach & CG (Amber)
    final trajPath = Path();
    var first = true;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final m = p.length > 7 ? p[7].toDouble() : 0.0;
      final cg = p.length > 9 ? p[9].toDouble() : 0.0;

      if (cg <= 0) continue;

      final x = toX(m);
      final y = toY(cg);

      if (first) {
        trajPath.moveTo(x, y);
        first = false;
      } else {
        trajPath.lineTo(x, y);
      }
    }

    final trajPaint = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(trajPath, trajPaint);
  }

  @override
  bool shouldRepaint(covariant _CgCorridorPainter oldDelegate) {
    return oldDelegate.track.length != track.length ||
        oldDelegate.colors != colors;
  }
}
