import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'lcd_theme.dart';

Widget cautionStripe() => CustomPaint(painter: CautionStripePainter());

class AircraftPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = lcdAmber
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final dot = Paint()..color = lcdRed;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final path = Path()
      ..moveTo(0, cy)
      ..lineTo(cx - 18, cy)
      ..lineTo(cx - 12, cy + 6)
      ..lineTo(cx, cy)
      ..lineTo(cx + 12, cy + 6)
      ..lineTo(cx + 18, cy)
      ..lineTo(size.width, cy);

    canvas.drawPath(path, p);
    canvas.drawCircle(Offset(cx, cy), 3, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class DroopNosePainter extends CustomPainter {
  final double angle; // 0 = retracted, 12.5 = fully down

  const DroopNosePainter({required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final bodyPaint = Paint()
      ..color = const Color(0xFF334155)
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = lcdAccent
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final cy = size.height * 0.45;

    // Fuselage body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, cy - 8, size.width - 40, 16),
        const Radius.circular(4),
      ),
      bodyPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(20, cy - 8, size.width - 40, 16),
        const Radius.circular(4),
      ),
      borderPaint,
    );

    // Droop nose pivot
    final droopAngleRad = angle * 3.14159 / 180.0;
    canvas.save();
    canvas.translate(20, cy);
    canvas.rotate(droopAngleRad * 1.2);

    final nosePath = Path()
      ..moveTo(0, 0)
      ..lineTo(-22, -5)
      ..lineTo(-22, 5)
      ..close();
    canvas.drawPath(nosePath, bodyPaint);
    canvas.drawPath(nosePath, borderPaint..color = angle > 0 ? lcdAmber : lcdAccent);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DroopNosePainter old) => old.angle != angle;
}

class CompassTapePainter extends CustomPainter {
  final double heading;

  const CompassTapePainter({required this.heading});

  @override
  void paint(Canvas canvas, Size size) {
    final tp = TextPainter(textDirection: TextDirection.ltr);
    final tickPaint = Paint()
      ..color = lcdMuted
      ..strokeWidth = 1.0;

    final cx = size.width / 2;

    for (int d = (heading - 45).floor(); d <= (heading + 45); d++) {
      final norm = (d + 360) % 360;
      final x = cx + (d - heading) * 4.0;
      if (x < 0 || x > size.width) continue;

      if (norm % 5 == 0) {
        canvas.drawLine(Offset(x, size.height - 10), Offset(x, size.height), tickPaint);

        if (norm % 10 == 0) {
          String lbl;
          if (norm == 0) { lbl = 'N'; }
          else if (norm == 90) { lbl = 'E'; }
          else if (norm == 180) { lbl = 'S'; }
          else if (norm == 270) { lbl = 'W'; }
          else { lbl = norm.toString().padLeft(3, '0'); }

          final isCardinal = lbl.length == 1;

          tp.text = TextSpan(
            text: lbl,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 8,
              fontWeight: FontWeight.bold,
              color: isCardinal ? lcdAccent : lcdMuted,
            ),
          );
          tp.layout();
          tp.paint(canvas, Offset(x - tp.width / 2, 4));
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CompassTapePainter old) => old.heading != heading;
}

class CautionStripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const stripes = 8;
    final h = size.height / stripes;

    for (int i = 0; i < stripes; i++) {
      paint.color = i.isEven
          ? lcdRed.withValues(alpha: 0.5)
          : Colors.greenAccent.withValues(alpha: 0.5);
      canvas.drawRect(Rect.fromLTWH(0, i * h, size.width, h), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
