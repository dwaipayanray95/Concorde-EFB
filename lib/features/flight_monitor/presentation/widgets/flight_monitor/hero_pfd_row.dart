import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/formatters.dart';
import '../../../../../core/ui_text.dart';
import '../../../../../widgets/efb_flat_card.dart';
import '../../../data/models/telemetry_model.dart';

/// One compact primary-flight-data bar (MFD style): speeds, altitude,
/// vertical speed, attitude, gear and nose in a single row, so the fuel
/// schematic and CG -- the Concorde-specific data -- sit above the fold.
class HeroPfdRow extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const HeroPfdRow({super.key, required this.t, required this.isConnected});

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

    final cells = <_Cell>[
      _Cell('IAS', '${t.ias.round()}', unit: 'KT'),
      _Cell('MACH', t.mach.toStringAsFixed(2), color: colors.accent),
      _Cell('TAS', '${t.tas.round()}', unit: 'KT'),
      _Cell('GS', '${t.gs.round()}', unit: 'KT'),
      _Cell('ALT', numFormat.format(t.altitude.round()), unit: 'FT'),
      _Cell('V/S', '${vs > 0 ? '+' : ''}$vs', unit: 'FPM', color: vsColor),
      _Cell('HDG', '${t.heading.round().toString().padLeft(3, '0')}°'),
      _Cell('PITCH', '${t.pitch.toStringAsFixed(1)}°'),
      _Cell('ROLL', '${t.roll.toStringAsFixed(1)}°'),
      _Cell('GEAR', t.gearLabel, color: gearColor),
      _Cell('NOSE', t.droopLabel),
    ];

    return EfbFlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= 900) {
            return Row(
              children: [
                for (final c in cells)
                  Expanded(flex: c.label == 'ALT' ? 5 : 4, child: c),
              ],
            );
          }
          return Wrap(
            spacing: 4,
            runSpacing: 12,
            children: [
              for (final c in cells) SizedBox(width: 96, child: c),
            ],
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final Color? color;
  const _Cell(this.label, this.value, {this.unit, this.color});

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
        const SizedBox(height: 4),
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
                  size: 20,
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
