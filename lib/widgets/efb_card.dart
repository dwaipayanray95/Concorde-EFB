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
    return EfbFlatCard(
      padding: const EdgeInsets.all(24),
      accentTop: accentTop,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: uiText(
                  context,
                  size: 14,
                  weight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: colors.textPrimary,
                ),
              ),
              ?right,
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
