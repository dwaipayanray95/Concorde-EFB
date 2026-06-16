import 'dart:math' as math;
import 'package:flutter/material.dart';

class WindArrow extends StatelessWidget {
  final double? runwayHeading;
  final double? windDir;
  final double size;
  final Color color;

  const WindArrow({
    super.key,
    required this.runwayHeading,
    required this.windDir,
    this.size = 24.0,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (runwayHeading == null || windDir == null) {
      return SizedBox(
        width: size,
        height: size,
        child: const Center(child: Text('VRB', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold))),
      );
    }

    final relWind = ((windDir! - runwayHeading!) % 360 + 360) % 360;
    final arrowRotation = (relWind + 180) % 360;
    final arrowRadians = arrowRotation * math.pi / 180;
    final runwayRadians = runwayHeading! * math.pi / 180;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        color: color.withValues(alpha: 0.1),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Runway Indicator Graphic
          Transform.rotate(
            angle: runwayRadians,
            child: Container(
              width: size * 0.15,
              height: size * 0.8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(4, (index) => Container(
                  width: 2,
                  height: size * 0.1,
                  color: Colors.white.withValues(alpha: 0.8),
                )),
              ),
            ),
          ),
          // Wind Arrow Indicator
          Transform.rotate(
            angle: arrowRadians,
            child: Icon(Icons.arrow_upward_rounded, size: size * 0.6, color: color),
          ),
        ],
      ),
    );
  }
}
