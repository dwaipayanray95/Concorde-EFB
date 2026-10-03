import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/formatters.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';

/// Primary flight display: speed column | attitude indicator | altitude
/// column, with heading / ground speed / gear / nose underneath.
class PfdPanel extends StatelessWidget {
  final TelemetryModel t;
  const PfdPanel({super.key, required this.t});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final vs = t.vs.round();
    final vsColor = vs.abs() < 100
        ? colors.textPrimary
        : (vs > 0 ? colors.success : colors.accent);
    final gearColor = switch (t.gearLabel) {
      'DOWN' => colors.success,
      'TRANSIT' => colors.accent,
      _ => colors.textPrimary,
    };

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 210,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 112,
                  child: _SideColumn(
                    rows: [
                      _Readout(
                        'IAS',
                        '${t.ias.round()}',
                        unit: 'KT',
                        big: true,
                      ),
                      _Readout(
                        'MACH',
                        t.mach.toStringAsFixed(2),
                        color: colors.accent,
                        big: true,
                      ),
                      _Readout('TAS', '${t.tas.round()}', unit: 'KT'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CustomPaint(
                      painter: _AdiPainter(
                        pitchDeg: t.pitch,
                        rollDeg: t.roll,
                        sky: colors.adiSky,
                        ground: colors.adiGround,
                        marking: Colors.white,
                        symbol: colors.accent,
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'P ${t.pitch.toStringAsFixed(1)}°   R ${t.roll.toStringAsFixed(1)}°',
                            style: uiText(
                              context,
                              size: 10,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 124,
                  child: _SideColumn(
                    rows: [
                      _Readout(
                        'ALT',
                        numFormat.format(t.altitude.round()),
                        unit: 'FT',
                        big: true,
                      ),
                      _Readout(
                        'V/S',
                        '${vs > 0 ? '+' : ''}$vs',
                        unit: 'FPM',
                        color: vsColor,
                        big: true,
                      ),
                      _Readout('GS', '${t.gs.round()}', unit: 'KT'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: colors.divider),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Readout(
                  'HDG',
                  '${t.heading.round().toString().padLeft(3, '0')}°',
                ),
              ),
              Expanded(child: _Readout('GEAR', t.gearLabel, color: gearColor)),
              Expanded(child: _Readout('NOSE', t.droopLabel)),
              Expanded(child: _Readout('G', t.gForce.toStringAsFixed(2))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SideColumn extends StatelessWidget {
  final List<_Readout> rows;
  const _SideColumn({required this.rows});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: rows,
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? color;
  final bool big;
  const _Readout(
    this.label,
    this.value, {
    this.unit,
    this.color,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: uiText(
            context,
            size: 9,
            weight: FontWeight.w800,
            color: colors.textDim,
            letterSpacing: 1.2,
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: uiText(
                  context,
                  size: big ? 24 : 16,
                  weight: FontWeight.w800,
                  color: color ?? colors.textPrimary,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: uiText(
                    context,
                    size: 9,
                    weight: FontWeight.w700,
                    color: colors.textDim,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Classic attitude indicator: horizon rotated by roll and shifted by
/// pitch, a pitch ladder every 5° (labelled every 10°), a roll scale arc
/// with a pointer, and the fixed aircraft symbol.
class _AdiPainter extends CustomPainter {
  final double pitchDeg;
  final double rollDeg;
  final Color sky;
  final Color ground;
  final Color marking;
  final Color symbol;

  _AdiPainter({
    required this.pitchDeg,
    required this.rollDeg,
    required this.sky,
    required this.ground,
    required this.marking,
    required this.symbol,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final pxPerDeg = size.height / 50; // +/- 25 deg visible
    final diag = math.sqrt(size.width * size.width + size.height * size.height);

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-rollDeg * math.pi / 180);
    canvas.translate(0, pitchDeg * pxPerDeg);

    canvas.drawRect(Rect.fromLTRB(-diag, -diag, diag, 0), Paint()..color = sky);
    canvas.drawRect(
      Rect.fromLTRB(-diag, 0, diag, diag),
      Paint()..color = ground,
    );
    final line = Paint()
      ..color = marking
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(-diag, 0), Offset(diag, 0), line);

    final ladder = Paint()
      ..color = marking.withValues(alpha: 0.85)
      ..strokeWidth = 1.2;
    for (var d = -30; d <= 30; d += 5) {
      if (d == 0) continue;
      final y = -d * pxPerDeg;
      final half = d % 10 == 0 ? size.width * 0.16 : size.width * 0.08;
      canvas.drawLine(Offset(-half, y), Offset(half, y), ladder);
      if (d % 10 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: '${d.abs()}',
            style: TextStyle(
              color: marking,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(half + 4, y - tp.height / 2));
      }
    }
    canvas.restore();

    // Roll scale (fixed) + pointer (rotates with the aircraft's roll).
    final r = math.min(size.width, size.height) * 0.42;
    final scale = Paint()
      ..color = marking
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      (-90 - 60) * math.pi / 180,
      120 * math.pi / 180,
      false,
      scale,
    );
    for (final a in [-60, -45, -30, -20, -10, 0, 10, 20, 30, 45, 60]) {
      final rad = (a - 90) * math.pi / 180;
      final len = a % 30 == 0 ? 10.0 : 6.0;
      canvas.drawLine(
        c + Offset(math.cos(rad), math.sin(rad)) * r,
        c + Offset(math.cos(rad), math.sin(rad)) * (r - len),
        scale,
      );
    }
    final pr = (-rollDeg - 90) * math.pi / 180;
    final tip = c + Offset(math.cos(pr), math.sin(pr)) * (r - 12);
    final side = Offset(-math.sin(pr), math.cos(pr)) * 6;
    final inward = Offset(math.cos(pr), math.sin(pr)) * 10;
    canvas.drawPath(
      Path()
        ..moveTo(tip.dx, tip.dy)
        ..lineTo((tip - inward + side).dx, (tip - inward + side).dy)
        ..lineTo((tip - inward - side).dx, (tip - inward - side).dy)
        ..close(),
      Paint()..color = symbol,
    );

    // Fixed aircraft symbol.
    final sym = Paint()
      ..color = symbol
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    final w = size.width * 0.18;
    canvas.drawLine(c + Offset(-w - 26, 0), c + Offset(-26, 0), sym);
    canvas.drawLine(c + Offset(-26, 0), c + Offset(-26, 8), sym);
    canvas.drawLine(c + Offset(26, 0), c + Offset(w + 26, 0), sym);
    canvas.drawLine(c + Offset(26, 0), c + Offset(26, 8), sym);
    canvas.drawCircle(c, 3.5, Paint()..color = symbol);
  }

  @override
  bool shouldRepaint(_AdiPainter old) =>
      old.pitchDeg != pitchDeg ||
      old.rollDeg != rollDeg ||
      old.sky != sky ||
      old.ground != ground;
}
