import 'dart:ui';
import 'package:flutter/material.dart';
import '../core/ui_tokens.dart';

class EfbGlassContainer extends StatefulWidget {
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
  State<EfbGlassContainer> createState() => _EfbGlassContainerState();
}

class _EfbGlassContainerState extends State<EfbGlassContainer> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);
    
    // Animate border color and neon glows on hover
    final borderCol = _isHovered 
        ? UiTokens.accent.withValues(alpha: 0.40) 
        : Colors.white.withValues(alpha: 0.1);
        
    final hoverGlow = [
      if (_isHovered)
        BoxShadow(
          color: UiTokens.accent.withValues(alpha: 0.15),
          blurRadius: 20,
          spreadRadius: 2,
        ),
      ...?widget.boxShadow,
    ];

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Padding(
        padding: widget.margin ?? EdgeInsets.zero,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: hoverGlow,
          ),
          child: ClipRRect(
            borderRadius: radius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: widget.blur, sigmaY: widget.blur),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: widget.padding,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(color: borderCol, width: 1.0),
                  color: widget.color,
                  gradient: widget.color == null && widget.gradient == null
                      ? LinearGradient(
                          colors: [
                            Colors.white.withValues(alpha: 0.08),
                            Colors.white.withValues(alpha: 0.03),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : widget.gradient,
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
