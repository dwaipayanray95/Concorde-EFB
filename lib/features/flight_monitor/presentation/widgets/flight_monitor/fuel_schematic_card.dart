import 'package:flutter/material.dart';
import '../../../../../core/concorde_fuel_schematic.dart';
import '../../../../../core/concorde_fuel_svg_data.dart';
import '../../../../../core/formatters.dart';
import 'fm_theme.dart';
import 'fuel_schematic_painter.dart';

/// FUEL SYSTEM card: the real Concorde fuel tank diagram (traced from the
/// Wikimedia Commons vector source, see [ConcordeFuelSvgData]), with each of
/// the 13 tanks filling/draining live as fuel burns, a group legend, and
/// total fuel.
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
            'FUEL TANK LAYOUT — LIVE PER-TANK LEVELS',
            style: fmLabel(size: 9, color: fmTextDim, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          _SchematicPaint(chips: chips),
          const SizedBox(height: 16),
          // Single-line legend + total — it's just a reference key, doesn't
          // need a third of the card's width beside the diagram.
          Row(
            children: [
              _LegendDot(color: fmRed, label: 'FUEL TRANSFER — 1·2·3·4'),
              const SizedBox(width: 16),
              _LegendDot(color: fmBlue, label: 'MAIN — 5·5A·6·7·7A·8'),
              const SizedBox(width: 16),
              _LegendDot(color: fmMint, label: 'TRIM — 9·10·11'),
              const Spacer(),
              Text('TOTAL FUEL ', style: fmLabel(size: 10, letterSpacing: 0)),
              Text(
                '${numFormat.format(totalKg.round())} KG',
                style: fmMono(size: 15, weight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 6),
        Text(label, style: fmLabel(size: 9, color: fmTextSecondary, weight: FontWeight.w700, letterSpacing: 0.3)),
      ],
    );
  }
}

/// The real vector diagram (see [ConcordeFuelSvgData]), rotated 90°
/// counter-clockwise to landscape (nose left) so it reads naturally in a
/// wide card, each tank shape filled live from [chips].
class _SchematicPaint extends StatelessWidget {
  final List<FuelTankChip> chips;
  const _SchematicPaint({required this.chips});

  // Source canvas is portrait (nose-up); after the 90° rotation the
  // landscape box's true aspect ratio is height:width of the source canvas.
  static const double _aspectRatio =
      ConcordeFuelSvgData.canvasHeight / ConcordeFuelSvgData.canvasWidth;

  @override
  Widget build(BuildContext context) {
    // AspectRatio (unlike LayoutBuilder) supports intrinsic-dimension
    // queries, so it's safe inside the IntrinsicHeight elsewhere in this
    // tab that measures this subtree.
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: RotatedBox(
        quarterTurns: 3, // 90° counter-clockwise: nose-up source -> nose-left
        child: CustomPaint(
          painter: FuelSchematicPainter(chips),
          size: Size(ConcordeFuelSvgData.canvasWidth, ConcordeFuelSvgData.canvasHeight),
        ),
      ),
    );
  }
}
