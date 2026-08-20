import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/concorde_fuel_schematic.dart';
import '../../../../../core/concorde_fuel_svg_data.dart';

/// Paints the real Concorde fuel tank diagram (traced from the Wikimedia
/// Commons vector source, see [ConcordeFuelSvgData]) with each of the 13
/// tanks filled bottom-up by its live percentage, so tanks visibly drain and
/// fill as fuel burns — using genuine per-tank shapes rather than a static
/// raster with overlays.
class FuelSchematicPainter extends CustomPainter {
  final List<FuelTankChip> chips;
  final AppColors colors;

  FuelSchematicPainter({required this.chips, required this.colors})
      : super(repaint: null);

  static final Path _outlinePath = parseSvgPathData(ConcordeFuelSvgData.outline);
  static final List<Path> _wallPaths =
      ConcordeFuelSvgData.walls.map(parseSvgPathData).toList();
  static final Map<String, Path> _tankPaths = ConcordeFuelSvgData.tankPaths
      .map((id, d) => MapEntry(id, parseSvgPathData(d)));

  Color _groupColor(FuelTankGroup group) {
    switch (group) {
      case FuelTankGroup.fuelTransfer:
        return colors.departure;
      case FuelTankGroup.main:
        return colors.accent;
      case FuelTankGroup.trim:
        return colors.mvfr;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / ConcordeFuelSvgData.canvasWidth;
    canvas.save();
    canvas.scale(scale, scale);

    final wallPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = colors.dividerStrong;
    final outlinePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..color = colors.textDim;

    final byId = {for (final c in chips) c.id: c};
    for (final entry in _tankPaths.entries) {
      final tankId = entry.key;
      final tankPath = entry.value;
      final chip = byId[tankId];
      final group =
          ConcordeFuelSchematic.tankGroups[tankId] ?? FuelTankGroup.main;
      final color = _groupColor(group);
      final pct = chip == null ? 0.0 : (chip.pct / 100.0).clamp(0.0, 1.0);

      // Empty-tank outline so unfilled tanks are still visible.
      final emptyPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.55);
      canvas.drawPath(tankPath, emptyPaint);

      if (pct <= 0.0) continue;

      final bounds = ConcordeFuelSvgData.tankBounds[tankId]!;
      final top = bounds[1], bottom = bounds[3];
      final fillTop = bottom - (bottom - top) * pct;
      final clipRect =
          Rect.fromLTRB(bounds[0] - 4, fillTop, bounds[2] + 4, bottom + 4);

      canvas.save();
      canvas.clipPath(tankPath);
      canvas.clipRect(clipRect);
      final fillPaint = Paint()..color = color.withValues(alpha: 0.85);
      canvas.drawRect(clipRect, fillPaint);
      canvas.restore();
    }

    for (final wall in _wallPaths) {
      canvas.drawPath(wall, wallPaint);
    }
    canvas.drawPath(_outlinePath, outlinePaint);

    _drawLabels(canvas);

    canvas.restore();
  }

  void _drawLabels(Canvas canvas) {
    for (final entry in ConcordeFuelSvgData.labelPositions.entries) {
      _drawBadge(canvas, entry.value[0], entry.value[1], entry.key);
    }
  }

  void _drawBadge(Canvas canvas, double x, double y, String text) {
    const r = 13.0;
    final center = Offset(x, y);
    final bgPaint = Paint()..color = Colors.white;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = Colors.black87;
    canvas.drawCircle(center, r, bgPaint);
    canvas.drawCircle(center, r, strokePaint);

    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(covariant FuelSchematicPainter oldDelegate) {
    if (oldDelegate.colors != colors) return true;
    if (oldDelegate.chips.length != chips.length) return true;
    for (var i = 0; i < chips.length; i++) {
      if (oldDelegate.chips[i].kg != chips[i].kg) return true;
    }
    return false;
  }
}
