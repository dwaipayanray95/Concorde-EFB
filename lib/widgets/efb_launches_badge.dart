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
            boxShadow: [
              BoxShadow(
                color: colors.textPrimary.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  color: colors.surface,
                  child: Text(
                    'EFB LAUNCHES',
                    style: uiText(
                      context,
                      color: colors.textSecondary,
                      size: 10,
                      weight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  color: colors.accent,
                  child: Text(
                    numFormat.format(count),
                    style: uiText(
                      context,
                      color: Colors.white,
                      size: 10,
                      weight: FontWeight.bold,
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
