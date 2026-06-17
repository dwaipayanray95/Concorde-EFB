import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/ui_tokens.dart';
import 'efb_glass_container.dart';

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
    return EfbGlassContainer(
      padding: const EdgeInsets.all(24),
      blur: 20,
      borderRadius: UiTokens.borderRadius,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: GoogleFonts.plusJakartaSans(
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
