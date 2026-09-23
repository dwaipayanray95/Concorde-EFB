import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/badge_provider.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';

class EfbLaunchesBadge extends ConsumerWidget {
  const EfbLaunchesBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(visitorCountProvider);
    final numFormat = NumberFormat('#,###');
    final colors = context.colors;

    return countAsync.when(
      data: (count) {
        if (count == 0) {
          return Text(
            'EFB Launches: Offline',
            style: uiText(
              context,
              color: colors.textDim,
              size: 12,
              weight: FontWeight.bold,
            ),
          );
        }

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  color: colors.resultsBg,
                  child: Text(
                    'EFB LAUNCHES',
                    style: uiText(
                      context,
                      color: colors.textSecondary,
                      size: 9.5,
                      weight: FontWeight.w800,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  color: colors.accent,
                  child: Text(
                    numFormat.format(count),
                    style: uiText(
                      context,
                      color: const Color(0xFF101012),
                      size: 10,
                      weight: FontWeight.w900,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Text(
        'Loading launches...',
        style: uiText(context, color: colors.textDim, size: 12),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}
