import 'package:flutter/material.dart';
import '../core/app_colors.dart';

class EfbFlatCard extends StatelessWidget {
  final Widget child;
  final Color? accentTop;
  final EdgeInsetsGeometry? padding;
  final Color? background;
  final BorderRadius? borderRadius;

  const EfbFlatCard({
    super.key,
    required this.child,
    this.accentTop,
    this.padding,
    this.background,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: background ?? colors.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(16),
        border: accentTop != null
            ? Border(
                top: BorderSide(color: accentTop!, width: 4),
                left: BorderSide(color: colors.dividerStrong.withValues(alpha: 0.5), width: 1),
                right: BorderSide(color: colors.dividerStrong.withValues(alpha: 0.5), width: 1),
                bottom: BorderSide(color: colors.dividerStrong.withValues(alpha: 0.5), width: 1),
              )
            : Border.all(
                color: colors.dividerStrong.withValues(alpha: 0.6),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.14),
            blurRadius: 16,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
