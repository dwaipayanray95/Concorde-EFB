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
        borderRadius: borderRadius ?? BorderRadius.circular(20),
        border: accentTop != null
            ? Border(top: BorderSide(color: accentTop!, width: 5))
            : null,
        boxShadow: [
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.08),
            blurRadius: 24,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: colors.textPrimary.withValues(alpha: 0.06),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}
