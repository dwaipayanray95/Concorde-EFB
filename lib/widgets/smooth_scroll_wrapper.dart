import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

class SmoothScrollWrapper extends StatefulWidget {
  final Widget child;
  final ScrollController controller;
  final double scrollSpeedMultiplier;

  const SmoothScrollWrapper({
    super.key,
    required this.child,
    required this.controller,
    this.scrollSpeedMultiplier = 2.0,
  });

  @override
  State<SmoothScrollWrapper> createState() => _SmoothScrollWrapperState();
}

class _SmoothScrollWrapperState extends State<SmoothScrollWrapper> {
  double _targetOffset = 0.0;
  bool _isAnimating = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateOffsetFromSystem);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateOffsetFromSystem);
    super.dispose();
  }

  void _updateOffsetFromSystem() {
    if (!_isAnimating && widget.controller.hasClients) {
      _targetOffset = widget.controller.offset;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: (pointerSignal) {
        if (pointerSignal is PointerScrollEvent) {
          if (!widget.controller.hasClients) return;

          final scrollAmount = pointerSignal.scrollDelta.dy * widget.scrollSpeedMultiplier;
          final minScroll = widget.controller.position.minScrollExtent;
          final maxScroll = widget.controller.position.maxScrollExtent;

          _targetOffset = (_targetOffset + scrollAmount).clamp(minScroll, maxScroll);

          _isAnimating = true;
          widget.controller.animateTo(
            _targetOffset,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
          ).then((_) {
            _isAnimating = false;
          });
        }
      },
      child: widget.child,
    );
  }
}
