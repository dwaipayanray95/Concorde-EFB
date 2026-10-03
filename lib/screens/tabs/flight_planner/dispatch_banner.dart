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
        ? ('GO · CAUTION', colors.accent, AppColors.dark.bg)
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
    final dim = fg.withValues(alpha: 0.8);
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
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              d.isGo
                  ? (d.cautions.isEmpty
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded)
                  : Icons.block,
              size: 16,
              color: fg,
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
              child: Text(
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
      ),
    );
  }
}
