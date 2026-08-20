import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../core/concorde_fuel_schematic.dart';
import '../../../../../core/concorde_fuel_svg_data.dart';
import '../../../../../core/formatters.dart';
import '../../../../../widgets/efb_flat_card.dart';
import 'fuel_schematic_painter.dart';

/// FUEL SYSTEM card: the real Concorde fuel tank diagram (traced from the
/// Wikimedia Commons vector source, see [ConcordeFuelSvgData]), with each of
/// the 13 tanks filling/draining live as fuel burns, a group legend, and
/// total fuel.
class FuelSchematicCard extends StatelessWidget {
  final List<FuelTankChip> chips;
  final double totalKg;

  const FuelSchematicCard({
    super.key,
    required this.chips,
    required this.totalKg,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return EfbFlatCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FUEL SYSTEM  ·  13-TANK SCHEMATIC',
            style: uiText(
              context,
              size: 11,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'FUEL TANK LAYOUT — LIVE PER-TANK LEVELS',
            style: uiText(
              context,
              size: 9,
              color: colors.textDim,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          _SchematicPaint(chips: chips),
          const SizedBox(height: 16),
          Row(
            children: [
              _LegendDot(
                color: colors.departure,
                label: 'FUEL TRANSFER — 1·2·3·4',
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: colors.accent,
                label: 'MAIN — 5·5A·6·7·7A·8',
              ),
              const SizedBox(width: 16),
              _LegendDot(
                color: colors.mvfr,
                label: 'TRIM — 9·10·11',
              ),
              const Spacer(),
              Text(
                'TOTAL FUEL ',
                style: uiText(
                  context,
                  size: 10,
                  color: colors.textDim,
                  letterSpacing: 0,
                ),
              ),
              Text(
                '${numFormat.format(totalKg.round())} KG',
                style: uiText(
                  context,
                  size: 15,
                  weight: FontWeight.w900,
                  color: colors.textPrimary,
                ),
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
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: uiText(
            context,
            size: 9,
            color: colors.textSecondary,
            weight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _SchematicPaint extends StatelessWidget {
  final List<FuelTankChip> chips;
  const _SchematicPaint({required this.chips});

  static const double _aspectRatio =
      ConcordeFuelSvgData.canvasHeight / ConcordeFuelSvgData.canvasWidth;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: RotatedBox(
        quarterTurns: 3,
        child: CustomPaint(
          painter: FuelSchematicPainter(chips: chips, colors: colors),
          size: Size(
            ConcordeFuelSvgData.canvasWidth,
            ConcordeFuelSvgData.canvasHeight,
          ),
        ),
      ),
    );
  }
}
