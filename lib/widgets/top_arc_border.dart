import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Wraps [child] in a rounded card whose only "border" is a reactive
/// colored band across the top -- full thickness along the flat top edge,
/// tapering smoothly (not a hard clip) into the corners until it merges
/// with the card's own rounded edge right where the corner meets the
/// straight side. Used to give a card an at-a-glance status color (e.g.
/// departure/arrival feasibility) without a competing side border.
class TopArcBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  final double strokeWidth;
  final Color? background;

  const TopArcBorder({
    super.key,
    required this.child,
    required this.color,
    this.radius = 20.0,
    this.strokeWidth = 8.0,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(radius), child: child),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _TopArcBorderPainter(
                  color: color,
                  radius: radius,
                  strokeWidth: strokeWidth,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a thick colored stroke along just the top rounded edge of a card
/// (following the actual corner curve at a constant thickness, then
/// stopping before the straight sides) -- a filled, tapering shape, not a
/// constant-width stroke, since a flat band clipped by the card's rounded
/// mask tapers to a point at the corner instead of curving smoothly, and a
/// constant-width stroke clipped flat leaves a visible kink where it ends.
class _TopArcBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double strokeWidth;

  const _TopArcBorderPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
  });

  static const _cornerSteps = 24;

  /// Inner-edge radius at corner param [t] (0 = flat-top tangent, 1 = side
  /// tangent, where it merges with the outer edge). Eased (not linear) so
  /// its derivative is zero at t=0 -- matching the flat band's horizontal
  /// inner edge -- instead of kinking right where the flat band meets the
  /// curve.
  double _innerRadius(double t) {
    final u = 1 - t;
    return radius - strokeWidth * (2 * u - u * u);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final rightCenter = Offset(size.width - radius, radius);
    final leftCenter = Offset(radius, radius);
    // Both corners start at their flat-top tangent (angle -90°, straight
    // up) and sweep 90° down to their straight-side tangent -- the right
    // corner sweeping clockwise (+), the left corner counterclockwise (-).
    const startAngle = -math.pi / 2;

    final path = Path()
      // Flat full-width band across the top, flush with the card's edges.
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0);

    // Right corner outer edge: constant radius, flush with the card
    // boundary, from the top tangent to the side tangent.
    for (var i = 1; i <= _cornerSteps; i++) {
      final angle = startAngle + (math.pi / 2) * (i / _cornerSteps);
      path.lineTo(
        rightCenter.dx + radius * math.cos(angle),
        rightCenter.dy + radius * math.sin(angle),
      );
    }
    // Right corner inner edge, walked backwards (side tangent -> top
    // tangent): its radius tapers from [radius] (touching the outer edge,
    // i.e. zero width) at the side tangent up to (radius - strokeWidth) at
    // the top tangent, so the band's two edges merge into one point at the
    // side instead of being sliced off with a flat cut.
    for (var i = _cornerSteps; i >= 0; i--) {
      final t = i / _cornerSteps;
      final angle = startAngle + (math.pi / 2) * t;
      final r = _innerRadius(t);
      path.lineTo(
        rightCenter.dx + r * math.cos(angle),
        rightCenter.dy + r * math.sin(angle),
      );
    }

    path.lineTo(radius, strokeWidth);

    // Left corner inner edge (top tangent -> side tangent): tapers from
    // (radius - strokeWidth) at the top down to [radius] (merging with the
    // outer edge) at the side.
    for (var i = 1; i <= _cornerSteps; i++) {
      final t = i / _cornerSteps;
      final angle = startAngle - (math.pi / 2) * t;
      final r = _innerRadius(t);
      path.lineTo(
        leftCenter.dx + r * math.cos(angle),
        leftCenter.dy + r * math.sin(angle),
      );
    }
    // Left corner outer edge, walked backwards (side tangent -> top
    // tangent), closing back to the path's start point.
    for (var i = _cornerSteps; i >= 0; i--) {
      final angle = startAngle - (math.pi / 2) * (i / _cornerSteps);
      path.lineTo(
        leftCenter.dx + radius * math.cos(angle),
        leftCenter.dy + radius * math.sin(angle),
      );
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TopArcBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.radius != radius ||
      oldDelegate.strokeWidth != strokeWidth;
}
