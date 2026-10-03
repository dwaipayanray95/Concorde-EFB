import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../providers/efb_providers.dart';

/// One-glance dispatch decision for the whole plan: GO, GO with cautions,
/// or NO-GO with every blocking reason listed.
class DispatchBanner extends ConsumerWidget {
  const DispatchBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final d = ref.watch(dispatchSummaryProvider);
    final (label, color, fg) = !d.isGo
        ? ('NO-GO', colors.error, Colors.white)
        : d.cautions.isNotEmpty
        ? ('GO · CAUTION', colors.accent, AppColors.dark.bg)
        : ('GO', colors.success, AppColors.dark.bg);
    final items = [
      ...d.noGo.map((t) => (t, true)),
      ...d.cautions.map((t) => (t, false)),
    ];

    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  d.isGo
                      ? (d.cautions.isEmpty
                            ? Icons.check_circle
                            : Icons.warning_amber_rounded)
                      : Icons.block,
                  size: 14,
                  color: fg,
                ),
                const SizedBox(width: 6),
                Text(
                  'DISPATCH $label',
                  style: uiText(
                    context,
                    size: 11,
                    weight: FontWeight.w900,
                    color: fg,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: items.isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'All fuel, weight, runway and weather checks passed.',
                      style: uiText(
                        context,
                        size: 11,
                        weight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: items.map((i) {
                      final c = i.$2 ? colors.error : colors.accent;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: c.withValues(alpha: 0.8)),
                        ),
                        child: Text(
                          i.$1.toUpperCase(),
                          style: uiText(
                            context,
                            size: 9.5,
                            weight: FontWeight.w800,
                            color: c,
                            letterSpacing: 0.5,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
