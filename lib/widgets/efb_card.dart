import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';
import 'top_arc_border.dart';

class EfbCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? right;
  final Color? accentTop;
  final IconData? icon;

  const EfbCard({
    super.key,
    required this.title,
    required this.child,
    this.right,
    this.accentTop,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accent = accentTop ?? colors.cardAccent;

    return TopArcBorder(
      color: accent,
      background: colors.resultsBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: colors.resultsBg,
              border: Border(
                bottom: BorderSide(color: colors.dividerStrong.withValues(alpha: 0.5), width: 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 14,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                if (icon != null) ...[
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: uiText(
                      context,
                      size: 12,
                      weight: FontWeight.w900,
                      letterSpacing: 1.8,
                      height: 1,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ?right,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(20), child: child),
        ],
      ),
    );
  }
}
