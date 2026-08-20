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
          // Folder tab header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: const BorderRadius.only(
                    bottomRight: Radius.circular(14),
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
                  padding: const EdgeInsets.only(top: 8, right: 16),
                  child: right!,
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: child,
          ),
        ],
      ),
    );
  }
}
