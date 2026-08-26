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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: colors.resultsBg,
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 16, color: accent),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: uiText(
                      context,
                      size: 12,
                      weight: FontWeight.w900,
                      letterSpacing: 2,
                      height: 1,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                ?right,
              ],
            ),
          ),
          Padding(padding: const EdgeInsets.all(24), child: child),
        ],
      ),
    );
  }
}
