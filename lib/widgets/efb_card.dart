import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';
import 'efb_flat_card.dart';

class EfbCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? right;
  final Color? accentTop;

  const EfbCard({
    super.key,
    required this.title,
    required this.child,
    this.right,
    this.accentTop,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final accentColor = accentTop ?? colors.accent;

    return EfbFlatCard(
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Attached flightstrip header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              border: Border(
                left: BorderSide(color: accentColor, width: 5),
                bottom: BorderSide(color: colors.divider),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title.toUpperCase(),
                  style: uiText(
                    context,
                    size: 12,
                    weight: FontWeight.w900,
                    letterSpacing: 2,
                    color: accentColor,
                  ),
                ),
                const Spacer(),
                ?right,
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: child,
          ),
        ],
      ),
    );
  }
}
