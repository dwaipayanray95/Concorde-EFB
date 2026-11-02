import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../providers/efb_providers.dart';

/// One-glance dispatch decision for the whole plan: GO, GO with cautions,
/// or NO-GO with every blocking reason listed.
class DispatchBanner extends ConsumerStatefulWidget {
  const DispatchBanner({super.key});

  @override
  ConsumerState<DispatchBanner> createState() => _DispatchBannerState();
}

class _DispatchBannerState extends ConsumerState<DispatchBanner> {
  /// On short (phone-landscape) screens the banner starts as a single line
  /// and expands on tap.
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final d = ref.watch(dispatchSummaryProvider);
    final (label, color, fg) = !d.isGo
        ? ('NO-GO', colors.error, Colors.white)
        : d.cautions.isNotEmpty
        ? ('GO · CAUTION', colors.surface, colors.textPrimary)
        : ('GO', colors.success, Colors.white);
    final allItems = [
      ...d.noGo.map((t) => (t, true)),
      ...d.cautions.map((t) => (t, false)),
    ];
    final compact = MediaQuery.sizeOf(context).height < 560 && !_expanded;
    final items = compact ? allItems.take(1).toList() : allItems;
    final hidden = allItems.length - items.length;

    // Flat, solid status block (same language as the METAR strip): the
    // whole banner is the status colour, text sits on it.
    final dim = d.isGo && d.cautions.isNotEmpty
        ? colors.textDim
        : fg.withValues(alpha: 0.8);
    final neutral = d.isGo && d.cautions.isNotEmpty;
    // When dispatch is GO, the numbers the crew needs at a glance.
    final quick = d.isGo ? _quickFigures() : const <(String, String)>[];
    return GestureDetector(
      onTap: allItems.length > 1
          ? () => setState(() => _expanded = !_expanded)
          : null,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: compact ? 8 : 11,
        ),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: neutral
              ? Border.all(color: colors.dividerStrong, width: 1.2)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  d.isGo
                      ? (d.cautions.isEmpty
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded)
                      : Icons.block,
                  size: 16,
                  color: neutral ? colors.accent : fg,
                ),
                const SizedBox(width: 8),
                Text(
                  'DISPATCH $label',
                  style: uiText(
                    context,
                    size: 13,
                    weight: FontWeight.w900,
                    color: fg,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 12),
                Container(width: 1, height: 16, color: dim),
                const SizedBox(width: 12),
                Expanded(
                  // Clean GO: the quick figures sit right in this row, so
                  // the banner is one strip.
                  child: items.isEmpty && quick.isNotEmpty && compact
                      ? _figures(context, quick, fg, dim)
                      : Text(
                          items.isEmpty
                              ? 'All fuel, weight, runway and weather checks passed.'
                              : [
                                  ...items.map((i) => i.$1.toUpperCase()),
                                  if (hidden > 0) '+$hidden MORE',
                                ].join('  ·  '),
                          maxLines: compact ? 1 : 3,
                          overflow: TextOverflow.ellipsis,
                          style: uiText(
                            context,
                            size: 11,
                            weight: FontWeight.w700,
                            color: fg,
                            letterSpacing: 0.4,
                          ),
                        ),
                ),
              ],
            ),
            if (quick.isNotEmpty && !compact) ...[
              const SizedBox(height: 8),
              Container(height: 1, color: dim.withValues(alpha: 0.35)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 16,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _vSpeedTiles(context, quick),
                  _figures(
                    context,
                    quick.where((e) => !_vKeys.contains(e.$1)).toList(),
                    fg,
                    dim,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _vKeys = {'V1', 'VR', 'V2'};

  /// V1 / VR / V2 as big standalone tiles so the crew can read them from
  /// across the flight deck.
  Widget _vSpeedTiles(BuildContext context, List<(String, String)> quick) {
    final colors = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (k, v) in quick.where((e) => _vKeys.contains(e.$1)))
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.dark.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.accent, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  k,
                  style: uiText(
                    context,
                    size: 11,
                    weight: FontWeight.w800,
                    color: colors.accent,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  v,
                  style: uiText(
                    context,
                    size: 28,
                    weight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _figures(
    BuildContext context,
    List<(String, String)> quick,
    Color fg,
    Color dim,
  ) {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        for (final (k, v) in quick)
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$k ',
                  style: uiText(
                    context,
                    size: 10,
                    weight: FontWeight.w700,
                    color: dim,
                    letterSpacing: 0.8,
                  ),
                ),
                TextSpan(
                  text: v,
                  style: uiText(
                    context,
                    size: 14,
                    weight: FontWeight.w900,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// V-speeds, weights, fuel, level and runways for a GO plan.
  List<(String, String)> _quickFigures() {
    final to = ref.watch(takeoffSpeedsProvider);
    final ldg = ref.watch(landingSpeedsProvider);
    final w = ref.watch(weightsProvider);
    final mission = ref.watch(missionProfileProvider);
    // The level actually flown (can be below the selected one on a short
    // sector).
    final fl = mission.targetCruiseFl;
    final depRwy = ref.watch(departureRunwayProvider)?.id;
    final arrRwy = ref.watch(arrivalRunwayProvider)?.id;
    String t(double kg) => '${(kg / 1000).toStringAsFixed(1)} T';
    return [
      ('V1', '${to.v1.round()}'),
      ('VR', '${to.vr.round()}'),
      ('V2', '${to.v2.round()}'),
      ('TOW', t(w.tow)),
      ('FUEL', t(w.fuelOnBoard)),
      ('FL', fl.toString().padLeft(3, '0')),
      if (depRwy != null) ('DEP', depRwy),
      ('LW', t(w.lw)),
      ('VAPP', '${ldg.vapp.round()}'),
      if (arrRwy != null) ('ARR', arrRwy),
    ];
  }
}
