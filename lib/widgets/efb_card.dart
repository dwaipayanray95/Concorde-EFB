import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Precision avionics chassis styling
    final cardBg = colors.resultsBg;
    final titlebarBg = isDark ? const Color(0xFF141417) : const Color(0xFFEBEBEF);
    final borderColor = accentTop ?? colors.dividerStrong.withValues(alpha: isDark ? 0.7 : 0.85);
    final hasCustomAccent = accentTop != null;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: borderColor,
          width: hasCustomAccent ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.28 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Integrated Avionics Titlebar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
            decoration: BoxDecoration(
              color: titlebarBg,
              border: Border(
                bottom: BorderSide(
                  color: colors.dividerStrong.withValues(alpha: isDark ? 0.5 : 0.7),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              children: [
                // Signature Amber Instrument Indicator Pip
                Container(
                  width: 3,
                  height: 12,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: accentTop ?? colors.accent,
                    borderRadius: BorderRadius.circular(1.5),
                  ),
                ),
                if (icon != null) ...[
                  Icon(icon, size: 14, color: accentTop ?? colors.accent),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                ?right,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: child,
          ),
        ],
      ),
    );
  }
}
