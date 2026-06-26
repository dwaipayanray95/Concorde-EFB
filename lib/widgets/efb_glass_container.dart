import 'dart:ui';
import 'package:flutter/material.dart';

class EfbGlassContainer extends StatelessWidget {
  final Widget child;
  final double blur;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Gradient? gradient;
  final List<BoxShadow>? boxShadow;

  const EfbGlassContainer({
    super.key,
    required this.child,
    this.blur = 15.0,
    this.borderRadius,
    this.padding,
    this.margin,
    this.color,
    this.gradient,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(16);
    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: boxShadow,
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.0),
                color: color,
                gradient: color == null && gradient == null
                    ? LinearGradient(
                        colors: [
                          Colors.white.withValues(alpha: 0.08),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : gradient,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
