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
    final tabBg = accentTop ?? colors.accent;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Popping folder tab sitting on top of the card
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: tabBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Text(
                title.toUpperCase(),
                style: uiText(
                  context,
                  size: 11,
                  weight: FontWeight.w900,
                  letterSpacing: 2,
                  color: Colors.white,
                ),
              ),
            ),
            if (right != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 6, right: 8),
                child: right!,
              ),
          ],
        ),
        // Main card body below the tab
        EfbFlatCard(
          padding: const EdgeInsets.all(24),
          child: child,
        ),
      ],
    );
  }
}
