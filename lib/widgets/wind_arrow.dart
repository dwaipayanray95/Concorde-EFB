import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
        child: Center(
          child: Text(
            'VRB',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    }

    // Calculate wind direction relative to the runway.
    // windDir is where the wind is coming FROM.
    // runwayHeading is where the nose of the plane points.
    final relWind = ((windDir! - runwayHeading!) % 360 + 360) % 360;
    
    // We want the runway graphic to always be straight UP (vertical).
    // The runway graphic is drawn vertically by default, so rotation is 0.
    final runwayRadians = 0.0;
    
    // The arrow icon points UP by default.
    // If we have a direct headwind (relWind = 0), the wind is coming FROM straight ahead,
    // meaning the arrow should point DOWN (180 degrees) towards the bottom of the runway.
    final arrowRotation = (relWind + 180) % 360;
    final arrowRadians = arrowRotation * math.pi / 180;

    return SizedBox(
      width: size,
      height: size,
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
