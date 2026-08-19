import 'package:flutter/material.dart';
import '../../../../../core/concorde_fuel_schematic.dart';
import '../../../../../core/formatters.dart';
import 'fm_theme.dart';

/// FUEL SYSTEM card: the 13-tank plan-view schematic (from the DC Designs
/// ops manual) with live fill-percent chips overlaid, a group legend, and
/// total fuel on board.
class FuelSchematicCard extends StatelessWidget {
  final List<FuelTankChip> chips;
  final double totalKg;

  const FuelSchematicCard({super.key, required this.chips, required this.totalKg});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: fmCardDecoration(),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FUEL SYSTEM  ·  13-TANK SCHEMATIC', style: fmLabel()),
          const SizedBox(height: 10),
          Text(
            'TANK LAYOUT PER DC DESIGNS OPS MANUAL FUEL SCHEMATIC',
            style: fmLabel(size: 9, color: fmTextDim, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _SchematicImage(chips: chips),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendRow(color: fmAccent, label: 'FUEL TRANSFER (COLLECTOR) — TANKS 1 · 2 · 3 · 4'),
                    const SizedBox(height: 10),
                    _LegendRow(color: fmBlue, label: 'MAIN TANKS — 5 · 5A · 6 · 7 · 7A · 8'),
                    const SizedBox(height: 10),
                    _LegendRow(color: fmMint, label: 'TRIM TRANSFER — 9 · 10 · 11'),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.only(top: 14),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: fmBorder)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('TOTAL FUEL ON BOARD', style: fmLabel(size: 10, letterSpacing: 0)),
                          const SizedBox(height: 6),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(numFormat.format(totalKg.round()), style: fmMono(size: 30)),
                              const SizedBox(width: 4),
                              Text(' KG', style: fmLabel(size: 14, color: fmMuted, weight: FontWeight.w600, letterSpacing: 0)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: fmLabel(size: 10, color: fmTextSecondary, weight: FontWeight.w700, letterSpacing: 0))),
      ],
    );
  }
}

class _SchematicImage extends StatelessWidget {
  final List<FuelTankChip> chips;
  const _SchematicImage({required this.chips});

  @override
  Widget build(BuildContext context) {
    const width = 190.0;
    const height = 250.0;
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _AircraftOutlinePainter()),
          ),
          for (final chip in chips)
            Positioned(
              left: (width - 12) * chip.left / 100.0,
              top: (height - 12) * chip.top / 100.0,
              child: FractionalTranslation(
                translation: const Offset(-0.5, 0.6),
                child: _TankChip(chip: chip),
              ),
            ),
        ],
      ),
    );
  }
}

/// Simplified Concorde plan-view (delta wing + slender fuselage) drawn as a
/// vector outline, sized to match the percent-coordinate tank positions in
/// [ConcordeFuelSchematic.tankPositions]. Used instead of a raster manual
/// scan so the schematic has no external asset dependency.
class _AircraftOutlinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    Offset pt(double xPct, double yPct) => Offset(size.width * xPct / 100, size.height * yPct / 100);

    final fill = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;

    // Delta wing + fuselage outline, symmetric about the vertical centerline.
    final outline = Path()
      ..moveTo(pt(48, 6).dx, pt(48, 6).dy) // nose tip
      ..lineTo(pt(44, 24).dx, pt(44, 24).dy)
      ..lineTo(pt(4, 68).dx, pt(4, 68).dy) // left wingtip
      ..lineTo(pt(24, 68).dx, pt(24, 68).dy)
      ..lineTo(pt(43, 82).dx, pt(43, 82).dy)
      ..lineTo(pt(43, 94).dx, pt(43, 94).dy) // tail left
      ..lineTo(pt(53, 94).dx, pt(53, 94).dy) // tail right
      ..lineTo(pt(53, 82).dx, pt(53, 82).dy)
      ..lineTo(pt(72, 68).dx, pt(72, 68).dy)
      ..lineTo(pt(92, 68).dx, pt(92, 68).dy) // right wingtip
      ..lineTo(pt(52, 24).dx, pt(52, 24).dy)
      ..close();

    canvas.drawPath(outline, fill);
    canvas.drawPath(outline, stroke);

    // Fuselage centerline, for reference.
    final centerline = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1;
    canvas.drawLine(pt(48, 6), pt(48, 94), centerline);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TankChip extends StatelessWidget {
  final FuelTankChip chip;
  const _TankChip({required this.chip});

  Color get _color => switch (chip.group) {
        FuelTankGroup.collector => fmAccent,
        FuelTankGroup.main => fmBlue,
        FuelTankGroup.trim => fmMint,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF05070C),
        border: Border.all(color: _color),
        borderRadius: BorderRadius.circular(3),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
      child: Text(
        '${chip.pct}%',
        style: fmMono(size: 7, color: _color, weight: FontWeight.w800),
      ),
    );
  }
}
