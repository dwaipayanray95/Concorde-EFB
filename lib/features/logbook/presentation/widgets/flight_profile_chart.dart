import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../core/formatters.dart';
import '../../../../core/ui_text.dart';
import '../../data/flight_log.dart';

enum ProfileMode { altMach, speeds, fuel }

/// Interactive dual-axis flight profile telemetry canvas with scrub cursor,
/// altitude gradient fill, Mach curve, milestone flags, and live readout bar.
class FlightProfileChart extends StatefulWidget {
  final FlightLog log;

  const FlightProfileChart({super.key, required this.log});

  @override
  State<FlightProfileChart> createState() => _FlightProfileChartState();
}

class _FlightProfileChartState extends State<FlightProfileChart> {
  ProfileMode _mode = ProfileMode.altMach;
  double? _scrubFrac;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final track = widget.log.track;

    if (track.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
        ),
        child: Center(
          child: Text(
            'No 5-second telemetry track recorded for this flight.',
            style: uiText(context, size: 12, color: colors.textSecondary),
          ),
        ),
      );
    }

    final pointCount = track.length;
    final selectedIdx = _scrubFrac == null
        ? (pointCount * 0.45).round().clamp(0, pointCount - 1)
        : (_scrubFrac! * (pointCount - 1)).round().clamp(0, pointCount - 1);
    final p = track[selectedIdx];

    // Decode point [epochSec, lat, lon, altFt, gsKt, iasKt, vsFpm, mach, fuelKg, cgPct]
    final altFt = p.length > 3 ? p[3].toDouble() : 0.0;
    final gsKt = p.length > 4 ? p[4].toDouble() : 0.0;
    final iasKt = p.length > 5 ? p[5].toDouble() : 0.0;
    final vsFpm = p.length > 6 ? p[6].toDouble() : 0.0;
    final mach = p.length > 7 ? p[7].toDouble() : 0.0;
    final fuelKg = p.length > 8 ? p[8].toDouble() : 0.0;
    final cgPct = p.length > 9 ? p[9].toDouble() : 0.0;

    // Elapsed time calculation
    final firstEpoch = track.first[0].toInt();
    final curEpoch = p[0].toInt();
    final elapsedSec = math.max(0, curEpoch - firstEpoch);
    final elapsedH = elapsedSec ~/ 3600;
    final elapsedM = (elapsedSec % 3600) ~/ 60;
    final elapsedStr =
        '+${elapsedH.toString().padLeft(2, '0')}:${elapsedM.toString().padLeft(2, '0')}';

    final zuluDt = DateTime.fromMillisecondsSinceEpoch(curEpoch * 1000, isUtc: true);
    final zuluStr =
        '${zuluDt.hour.toString().padLeft(2, '0')}:${zuluDt.minute.toString().padLeft(2, '0')}:${zuluDt.second.toString().padLeft(2, '0')}Z';

    // Phase inference
    String phase;
    if (altFt < 1000 && gsKt < 80) {
      phase = 'TAXI / GROUND';
    } else if (altFt < 28000 && mach < 0.95 && vsFpm > 500) {
      phase = 'SUBSONIC CLIMB';
    } else if (altFt >= 28000 && altFt < 50000 && mach >= 0.95 && mach < 1.70) {
      phase = 'TRANSONIC REHEAT';
    } else if (altFt >= 45000 && mach >= 1.70 && vsFpm > -500) {
      phase = mach >= 2.0 ? 'M2.0 SUPERCRUISE' : 'SUPERCRUISE';
    } else if (vsFpm < -1000) {
      phase = 'DECEL & DESCENT';
    } else {
      phase = 'APPROACH / ENROUTE';
    }

    final isReheat = mach >= 0.95 && mach <= 1.70 && vsFpm > 300;

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
          // Header & Layer Switcher
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 600;

              final titleBlock = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                        'MISSION PROFILE & TELEMETRY RECORDER',
                        style: uiText(
                          context,
                          size: 11,
                          weight: FontWeight.w900,
                          color: colors.accent,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Sampled at 5s interval (${track.length} points) · Drag or hover to inspect live point',
                    style: uiText(context, size: 10, color: colors.textSecondary),
                  ),
                ],
              );

              final modeButtons = Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: colors.resultsBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colors.dividerStrong.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _modeBtn('ALT + MACH', ProfileMode.altMach, colors),
                    _modeBtn('IAS / TAS', ProfileMode.speeds, colors),
                    _modeBtn('FUEL BURN', ProfileMode.fuel, colors),
                  ],
                ),
              );

              if (wide) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: titleBlock),
                    const SizedBox(width: 12),
                    modeButtons,
                  ],
                );
              } else {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    titleBlock,
                    const SizedBox(height: 10),
                    modeButtons,
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Synchronized Live Telemetry Readout Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.resultsBg,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: colors.dividerStrong.withValues(alpha: 0.5),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, c) {
                final wide = c.maxWidth >= 720;
                final mid = c.maxWidth >= 480;

                Widget cell(String label, String value, [Color? valColor]) =>
                    Column(
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
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            value,
                            style: uiText(
                              context,
                              size: 12,
                              weight: FontWeight.w900,
                              color: valColor ?? colors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    );

                final cells = [
                  cell('TIME (ZULU / ETE)', '$zuluStr ($elapsedStr)'),
                  cell(
                    'ALTITUDE',
                    'FL${(altFt / 100).round()} (${numFormat.format(altFt.round())} FT)',
                    colors.accent,
                  ),
                  cell(
                    'MACH NUMBER',
                    'M${mach.toStringAsFixed(2)}',
                    mach >= 1.0 ? colors.accent : const Color(0xFF06B6D4),
                  ),
                  cell(
                    'AIRSPEED',
                    '${iasKt.round()} IAS · ${gsKt.round()} GS',
                  ),
                  cell(
                    'VERTICAL SPEED',
                    '${vsFpm >= 0 ? '+' : ''}${vsFpm.round()} FPM ($phase)',
                    vsFpm > 500
                        ? colors.success
                        : (vsFpm < -500 ? colors.mvfr : colors.textPrimary),
                  ),
                  cell(
                    'FUEL ON BOARD',
                    fuelKg > 0 ? '${numFormat.format(fuelKg.round())} KG' : '--',
                  ),
                  cell(
                    'CG POSITION',
                    cgPct > 0 ? '${cgPct.toStringAsFixed(1)}% MAC' : '--',
                    cgPct >= 52.0 && cgPct <= 59.0 ? colors.success : colors.error,
                  ),
                  cell(
                    'STATE',
                    isReheat ? 'REHEAT (4×)' : 'DRY THRUST',
                    isReheat ? colors.error : colors.textDim,
                  ),
                ];

                if (wide) {
                  return Row(
                    children: [
                      for (var i = 0; i < cells.length; i++) ...[
                        if (i > 0) const SizedBox(width: 8),
                        Expanded(child: cells[i]),
                      ],
                    ],
                  );
                } else if (mid) {
                  return Column(
                    children: [
                      Row(
                        children: [
                          for (var i = 0; i < 4; i++) ...[
                            if (i > 0) const SizedBox(width: 8),
                            Expanded(child: cells[i]),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          for (var i = 4; i < 8; i++) ...[
                            if (i > 4) const SizedBox(width: 8),
                            Expanded(child: cells[i]),
                          ],
                        ],
                      ),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: cells[0]),
                          const SizedBox(width: 6),
                          Expanded(child: cells[1]),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: cells[2]),
                          const SizedBox(width: 6),
                          Expanded(child: cells[3]),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(child: cells[4]),
                          const SizedBox(width: 6),
                          Expanded(child: cells[5]),
                        ],
                      ),
                    ],
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 12),

          // The Interactive Dual-Axis Canvas
          LayoutBuilder(
            builder: (context, c) {
              return SizedBox(
                width: c.maxWidth,
                height: 240,
                child: GestureDetector(
                  onHorizontalDragDown: (details) =>
                      _handleScrub(details.localPosition.dx, c.maxWidth),
                  onHorizontalDragUpdate: (details) =>
                      _handleScrub(details.localPosition.dx, c.maxWidth),
                  child: CustomPaint(
                    size: Size(c.maxWidth, 240),
                    painter: _ProfileChartPainter(
                      track: track,
                      colors: colors,
                      mode: _mode,
                      scrubFrac: _scrubFrac ?? (selectedIdx / (pointCount - 1)),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // Legend & Hints
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 6,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  _legendItem('ALTITUDE (FL600)', colors.accent),
                  if (_mode == ProfileMode.altMach)
                    _legendItem('MACH NUMBER (2.2)', const Color(0xFF06B6D4)),
                  if (_mode == ProfileMode.speeds) ...[
                    _legendItem('IAS (KT)', const Color(0xFF06B6D4)),
                    _legendItem('GS (KT)', colors.departure),
                  ],
                  if (_mode == ProfileMode.fuel)
                    _legendItem('FUEL REMAINING', const Color(0xFF06B6D4)),
                  _legendItem('REHEAT ACTIVE', colors.error, isDot: true),
                ],
              ),
              Text(
                '* Scrub across chart to inspect synchronized parameters',
                style: uiText(context, size: 9, color: colors.textDim),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _handleScrub(double localX, double totalW) {
    const padL = 44.0;
    const padR = 44.0;
    final plotW = totalW - padL - padR;
    final frac = ((localX - padL) / plotW).clamp(0.0, 1.0);
    setState(() => _scrubFrac = frac);
  }

  Widget _modeBtn(String label, ProfileMode m, AppColors colors) {
    final active = _mode == m;
    return Material(
      color: active ? colors.accent : Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () => setState(() => _mode = m),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Text(
            label,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w900,
              color: active ? AppColors.dark.bg : colors.textSecondary,
              letterSpacing: 0.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, {bool isDot = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          isDot
              ? Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                )
              : Container(
                  width: 10,
                  height: 2.5,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
          const SizedBox(width: 5),
          Text(
            label,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
}

class _ProfileChartPainter extends CustomPainter {
  final List<List<num>> track;
  final AppColors colors;
  final ProfileMode mode;
  final double scrubFrac;

  _ProfileChartPainter({
    required this.track,
    required this.colors,
    required this.mode,
    required this.scrubFrac,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padL = 44.0;
    const padR = 44.0;
    const padT = 20.0;
    const padB = 24.0;

    final plotW = size.width - padL - padR;
    final plotH = size.height - padT - padB;

    if (track.length < 2 || plotW <= 0 || plotH <= 0) return;

    // Grid lines & Y-Axis Labels
    final gridPaint = Paint()
      ..color = colors.dividerStrong.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var i = 0; i <= 4; i++) {
      final y = padT + (plotH / 4) * i;
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);

      // Left labels: Altitude (FL600 -> FL0)
      final fl = 600 - i * 150;
      final tpL = TextPainter(
        text: TextSpan(
          text: 'FL$fl',
          style: TextStyle(
            color: colors.textDim,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpL.paint(canvas, Offset(padL - tpL.width - 6, y - tpL.height / 2));

      // Right labels: Mach or Speeds or Fuel
      String rText;
      Color rColor = const Color(0xFF06B6D4);
      switch (mode) {
        case ProfileMode.altMach:
          final mVal = (2.2 - i * (2.2 / 4)).toStringAsFixed(1);
          rText = 'M$mVal';
        case ProfileMode.speeds:
          final sVal = (1200 - i * 300).round();
          rText = '$sVal KT';
        case ProfileMode.fuel:
          final fVal = (96 - i * 24).round();
          rText = '${fVal}T';
      }

      final tpR = TextPainter(
        text: TextSpan(
          text: rText,
          style: TextStyle(
            color: rColor,
            fontSize: 9,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tpR.paint(canvas, Offset(size.width - padR + 6, y - tpR.height / 2));
    }

    // Concorde FL500-FL600 Supercruise corridor tint
    final yFL500 = padT + plotH * (1.0 - (50000 / 60000));
    final supercruiseRect = Rect.fromLTWH(padL, padT, plotW, yFL500 - padT);
    canvas.drawRect(
      supercruiseRect,
      Paint()..color = colors.accent.withValues(alpha: 0.04),
    );

    double getX(int idx) => padL + (idx / (track.length - 1)) * plotW;

    // Reheat Highlight Spans
    var inReheat = false;
    var reheatStart = 0;
    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final m = p.length > 7 ? p[7].toDouble() : 0.0;
      final vs = p.length > 6 ? p[6].toDouble() : 0.0;
      final active = m >= 0.95 && m <= 1.70 && vs > 200;

      if (active && !inReheat) {
        inReheat = true;
        reheatStart = i;
      } else if (!active && inReheat) {
        inReheat = false;
        final x1 = getX(reheatStart);
        final x2 = getX(i);
        canvas.drawRect(
          Rect.fromLTWH(x1, padT, x2 - x1, plotH),
          Paint()..color = colors.error.withValues(alpha: 0.12),
        );
      }
    }

    // Curve 1: Altitude Profile (Amber)
    final altPath = Path();
    final altFill = Path();
    var first = true;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final x = getX(i);
      final y = padT + plotH * (1.0 - (alt / 60000).clamp(0.0, 1.0));

      if (first) {
        altPath.moveTo(x, y);
        altFill.moveTo(x, padT + plotH);
        altFill.lineTo(x, y);
        first = false;
      } else {
        altPath.lineTo(x, y);
        altFill.lineTo(x, y);
      }
    }

    altFill.lineTo(padL + plotW, padT + plotH);
    altFill.close();

    // Fill underneath altitude
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          colors.accent.withValues(alpha: 0.25),
          colors.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, padT, size.width, plotH));
    canvas.drawPath(altFill, fillPaint);

    final altPaint = Paint()
      ..color = colors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(altPath, altPaint);

    // Curve 2: Secondary Data (Mach or Speeds or Fuel)
    final secPath = Path();
    first = true;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final x = getX(i);
      double normVal;

      switch (mode) {
        case ProfileMode.altMach:
          final m = p.length > 7 ? p[7].toDouble() : 0.0;
          normVal = (m / 2.2).clamp(0.0, 1.0);
        case ProfileMode.speeds:
          final tas = (p.length > 7 ? p[7].toDouble() : 0.0) * 580; // or GS
          normVal = (tas / 1200).clamp(0.0, 1.0);
        case ProfileMode.fuel:
          final f = p.length > 8 ? p[8].toDouble() : 0.0;
          normVal = (f / 96000).clamp(0.0, 1.0);
      }

      final y = padT + plotH * (1.0 - normVal);
      if (first) {
        secPath.moveTo(x, y);
        first = false;
      } else {
        secPath.lineTo(x, y);
      }
    }

    final secPaint = Paint()
      ..color = const Color(0xFF06B6D4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(secPath, secPaint);

    // Milestone Event Flags
    _drawMilestones(canvas, padL, plotW, padT, plotH);

    // Crosshair Scrubber Cursor
    final scrubX = padL + scrubFrac * plotW;
    final scrubPaint = Paint()
      ..color = colors.textPrimary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(Offset(scrubX, padT), Offset(scrubX, padT + plotH), scrubPaint);

    final curIdx = (scrubFrac * (track.length - 1)).round().clamp(0, track.length - 1);
    final curAlt = track[curIdx].length > 3 ? track[curIdx][3].toDouble() : 0.0;
    final dotY = padT + plotH * (1.0 - (curAlt / 60000).clamp(0.0, 1.0));

    canvas.drawCircle(Offset(scrubX, dotY), 4.5, Paint()..color = colors.textPrimary);
    canvas.drawCircle(Offset(scrubX, dotY), 3.0, Paint()..color = colors.accent);
  }

  void _drawMilestones(
    Canvas canvas,
    double padL,
    double plotW,
    double padT,
    double plotH,
  ) {
    // Find key milestone indices along the track
    int? takeoffIdx;
    int? m1Idx;
    int? tocIdx;
    int? todIdx;
    int? ldgIdx;

    for (var i = 0; i < track.length; i++) {
      final p = track[i];
      final alt = p.length > 3 ? p[3].toDouble() : 0.0;
      final m = p.length > 7 ? p[7].toDouble() : 0.0;
      final vs = p.length > 6 ? p[6].toDouble() : 0.0;

      if (takeoffIdx == null && alt > 500) takeoffIdx = i;
      if (m1Idx == null && m >= 1.0) m1Idx = i;
      if (tocIdx == null && alt >= 50000 && m >= 1.95) tocIdx = i;
      if (todIdx == null && i > track.length * 0.6 && vs < -1200) todIdx = i;
      if (alt < 200 && i > track.length * 0.9) ldgIdx = i;
    }

    void flag(int? idx, String label, Color c) {
      if (idx == null || idx < 0 || idx >= track.length) return;
      final x = padL + (idx / (track.length - 1)) * plotW;

      final p = Paint()
        ..color = c.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(x, padT), Offset(x, padT + plotH), p);

      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: c,
            fontSize: 8,
            fontWeight: FontWeight.w900,
            fontFamily: 'JetBrains Mono',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, padT - tp.height - 2));
    }

    flag(takeoffIdx, 'TAKEOFF', colors.success);
    flag(m1Idx, 'M1.0', const Color(0xFF8B5CF6));
    flag(tocIdx, 'FL500+', colors.accent);
    flag(todIdx, 'TOD', const Color(0xFF06B6D4));
    flag(ldgIdx, 'TOUCHDOWN', colors.success);
  }

  @override
  bool shouldRepaint(covariant _ProfileChartPainter oldDelegate) {
    return oldDelegate.track.length != track.length ||
        oldDelegate.colors != colors ||
        oldDelegate.mode != mode ||
        oldDelegate.scrubFrac != scrubFrac;
  }
}
