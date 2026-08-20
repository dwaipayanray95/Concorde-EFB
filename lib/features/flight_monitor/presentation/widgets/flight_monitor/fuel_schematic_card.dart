import 'package:flutter/material.dart';
import '../../../../../core/concorde_fuel_schematic.dart';
import '../../../../../core/formatters.dart';
import 'fm_theme.dart';

/// FUEL SYSTEM card: the real "Fuel Tank Layout Schematic" diagram (page 54
/// of the DC Designs ops manual, extracted directly from the source PDF)
/// with live fill-percent chips overlaid, a group legend, and total fuel.
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
            'FUEL TANK LAYOUT SCHEMATIC — DC DESIGNS OPS MANUAL, PG. 54',
            style: fmLabel(size: 9, color: fmTextDim, letterSpacing: 0.5),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(flex: 3, child: _SchematicImage(chips: chips)),
              const SizedBox(width: 24),
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LegendRow(color: fmRed, label: 'FUEL TRANSFER — TANKS 1 · 2 · 3 · 4'),
                    const SizedBox(height: 10),
                    _LegendRow(color: fmBlue, label: 'MAIN TANKS — 5 · 5A · 6 · 7 · 7A · 8'),
                    const SizedBox(height: 10),
                    _LegendRow(color: fmMint, label: 'TRIM TRANSFER — 9 · 10 · 11'),
                    const SizedBox(height: 10),
                    _LegendRow(color: fmYellow, label: 'ENGINE COLLECTOR TANKS'),
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

/// The real manual diagram, rotated 90° counter-clockwise to landscape
/// (nose left) so it reads naturally in a wide card. [ConcordeFuelSchematic.tankPositions]
/// was pixel-measured directly off this same source image, and
/// [ConcordeFuelSchematic.landscapeFraction] is exactly the fractional
/// equivalent of this rotation — so the live percentage chips always land
/// on the right tank regardless of layout size.
class _SchematicImage extends StatelessWidget {
  final List<FuelTankChip> chips;
  const _SchematicImage({required this.chips});

  // Source raster is 1446x2048 (portrait); after the 90° rotation the
  // landscape box's true aspect ratio is height:width of the source image.
  static const double _aspectRatio = 2048 / 1446;

  @override
  Widget build(BuildContext context) {
    // Fill whatever width the row gives this card's flex share, sized by
    // the image's real aspect ratio so it's never stretched/squished.
    // AspectRatio (unlike LayoutBuilder) supports intrinsic-dimension
    // queries, so it's safe inside the IntrinsicHeight elsewhere in this
    // tab that measures this subtree.
    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RotatedBox(
              quarterTurns: 3, // 90° counter-clockwise: nose-up source -> nose-left
              child: Image.asset(
                'assets/fuel_tank_schematic.png',
                fit: BoxFit.fill,
              ),
            ),
          ),
          for (final chip in chips)
            _positionedAt(chip.left, chip.top, _TankChip(chip: chip)),
        ],
      ),
    );
  }

  /// Positions a chip fractionally within the Stack using [Align] rather
  /// than pixel offsets — this needs no explicit width, so it works
  /// regardless of how much space the Expanded parent ends up giving it.
  Widget _positionedAt(double xPct, double yPct, Widget child) {
    final f = ConcordeFuelSchematic.landscapeFraction(xPct, yPct);
    return Align(
      alignment: Alignment(f.fx * 2 - 1, f.fy * 2 - 1),
      // Offset below the point rather than centered on it, so the chip
      // doesn't sit directly on top of the diagram's own numbered circle.
      child: FractionalTranslation(
        translation: const Offset(0, 0.9),
        child: child,
      ),
    );
  }
}

class _TankChip extends StatelessWidget {
  final FuelTankChip chip;
  const _TankChip({required this.chip});

  Color get _color => switch (chip.group) {
        FuelTankGroup.fuelTransfer => fmRed,
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
