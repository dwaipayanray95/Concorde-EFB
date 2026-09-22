import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_spacing.dart';
import '../core/ui_text.dart';
import '../widgets/efb_flat_card.dart';
import '../widgets/efb_card.dart';
import '../widgets/efb_text_field.dart';
import '../widgets/wind_arrow.dart';

/// Interactive Component Catalog & Design Lab.
/// Allows developers and designers to preview and verify all design system tokens,
/// colors, typography, and atomic widgets in isolation across themes.
class DesignLabScreen extends StatefulWidget {
  const DesignLabScreen({super.key});

  @override
  State<DesignLabScreen> createState() => _DesignLabScreenState();
}

class _DesignLabScreenState extends State<DesignLabScreen> {
  bool _isDark = true;
  double _windDeg = 45;
  final double _windKt = 18;

  @override
  Widget build(BuildContext context) {
    final colors = _isDark ? AppColors.dark : AppColors.light;

    return Theme(
      data: ThemeData(
        brightness: _isDark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: colors.bg,
        extensions: [colors],
      ),
      child: Scaffold(
        backgroundColor: colors.bg,
        appBar: AppBar(
          title: Text(
            'CONCORDE EFB — DESIGN LAB',
            style: AppTypography.sectionHeader(context, color: colors.textPrimary),
          ),
          backgroundColor: colors.surface,
          elevation: 0,
          actions: [
            Row(
              children: [
                Icon(_isDark ? Icons.dark_mode : Icons.light_mode, color: colors.accent, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _isDark ? 'DARK MODE' : 'LIGHT MODE',
                  style: AppTypography.caption(context, color: colors.textSecondary),
                ),
                Switch(
                  value: _isDark,
                  activeThumbColor: colors.accent,
                  onChanged: (val) => setState(() => _isDark = val),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: AppSpacing.pXl,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Color Palette Tokens
              _buildSectionTitle(context, '1. SEMANTIC COLOR TOKENS (AppColors)', colors),
              const SizedBox(height: AppSpacing.md),
              _buildColorGrid(colors),
              const SizedBox(height: AppSpacing.xxl),

              // 2. Typography Scale
              _buildSectionTitle(context, '2. TYPOGRAPHIC SCALE (AppTypography)', colors),
              const SizedBox(height: AppSpacing.md),
              _buildTypographyShowcase(context, colors),
              const SizedBox(height: AppSpacing.xxl),

              // 3. Core Component Cards & Atoms
              _buildSectionTitle(context, '3. ATOMIC COMPONENTS & CARDS', colors),
              const SizedBox(height: AppSpacing.md),
              _buildComponentShowcase(context, colors),
              const SizedBox(height: AppSpacing.xxl),

              // 4. Avionics Readout Simulation
              _buildSectionTitle(context, '4. AVIONICS GAUGES & METAR WIDGETS', colors),
              const SizedBox(height: AppSpacing.md),
              _buildAvionicsShowcase(context, colors),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, AppColors colors) {
    return Container(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: colors.dividerStrong, width: 1.5),
        ),
      ),
      child: Text(
        title,
        style: AppTypography.sectionHeader(context, color: colors.accent, letterSpacing: 1.2),
      ),
    );
  }

  Widget _buildColorGrid(AppColors colors) {
    final swatches = <MapEntry<String, Color>>[
      MapEntry('bg', colors.bg),
      MapEntry('surface', colors.surface),
      MapEntry('resultsBg', colors.resultsBg),
      MapEntry('inputBg', colors.inputBg),
      MapEntry('textPrimary', colors.textPrimary),
      MapEntry('textSecondary', colors.textSecondary),
      MapEntry('textDim', colors.textDim),
      MapEntry('accent', colors.accent),
      MapEntry('departure (VFR)', colors.departure),
      MapEntry('arrival (Sim)', colors.arrival),
      MapEntry('mvfr (Marginal)', colors.mvfr),
      MapEntry('error (IFR)', colors.error),
      MapEntry('lifr (Low IFR)', colors.lifr),
    ];

    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: swatches.map((s) {
        return Container(
          width: 130,
          padding: AppSpacing.pSm,
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadii.sm,
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: s.value,
                  borderRadius: AppRadii.xs,
                  border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.3)),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                s.key,
                style: AppTypography.caption(context, color: colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTypographyShowcase(BuildContext context, AppColors colors) {
    return EfbFlatCard(
      padding: AppSpacing.pLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Display: 20px Bold — CONCORDE SST 2.04 MACH',
              style: AppTypography.display(context, color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Section Header: 14px Semibold — TAKEOFF PERFORMANCE V-SPEEDS',
              style: AppTypography.sectionHeader(context, color: colors.accent)),
          const SizedBox(height: AppSpacing.sm),
          Text('Readout: 13px Bold — V1: 162 KT | VR: 198 KT | V2: 220 KT',
              style: AppTypography.readout(context, color: colors.textPrimary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Body: 12px Regular — Nominal transatlantic cruise burn 24.45 kg/NM, Non-RVSM snapping active.',
              style: AppTypography.body(context, color: colors.textSecondary)),
          const SizedBox(height: AppSpacing.sm),
          Text('Caption: 10px Bold — CAT III / FULL REHEAT ENGAGED / TRIM TANK 11 BALANCED',
              style: AppTypography.caption(context, color: colors.textDim)),
        ],
      ),
    );
  }

  Widget _buildComponentShowcase(BuildContext context, AppColors colors) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: EfbCard(
            title: 'SAMPLE EFB CARD',
            icon: Icons.flight_takeoff,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EfbTextField(
                  label: 'ICAO IDENTIFIER',
                  initialValue: 'EGLL',
                  onChanged: (_) {},
                  placeholder: 'e.g. EGLL',
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
                      ),
                      onPressed: () {},
                      child: Text('PRIMARY BUTTON', style: AppTypography.caption(context, color: Colors.white)),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: colors.dividerStrong),
                        shape: RoundedRectangleBorder(borderRadius: AppRadii.md),
                      ),
                      onPressed: () {},
                      child: Text('SECONDARY', style: AppTypography.caption(context, color: colors.textSecondary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvionicsShowcase(BuildContext context, AppColors colors) {
    return EfbFlatCard(
      padding: AppSpacing.pLg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              WindArrow(
                runwayHeading: 90,
                windDir: _windDeg,
                windSpeedKt: _windKt,
                runwayLabel: '09L',
              ),
              const SizedBox(width: AppSpacing.lg),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('WIND: ${_windDeg.round()}° at ${_windKt.round()} KT',
                      style: AppTypography.readout(context, color: colors.textPrimary)),
                  Text('Runway alignment vector with automated head/crosswind resolver',
                      style: AppTypography.caption(context, color: colors.textDim)),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Slider(
            value: _windDeg,
            min: 0,
            max: 360,
            activeColor: colors.accent,
            onChanged: (v) => setState(() => _windDeg = v),
          ),
        ],
      ),
    );
  }
}
