import 'package:flutter/material.dart';
import '../core/ui_tokens.dart';

class EfbCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? right;

  const EfbCard({
    super.key,
    required this.title,
    required this.child,
    this.right,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: UiTokens.surface.withValues(alpha: 0.4),
        borderRadius: UiTokens.borderRadius,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min, // Respect content size
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: UiTokens.textPrimary,
                ),
              ),
              if (right != null) right ?? const SizedBox.shrink(),
            ],
          ),
          const SizedBox(height: 24),
          child,
        ],
      ),
    );
  }
}
