import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:concorde_efb/widgets/efb_glass_container.dart';

class LandingReporter extends StatelessWidget {
  final double currentPitch;
  final bool isLanding;
  final double touchdownVS;
  final double touchdownPitch;
  final double touchdownGForce;

  const LandingReporter({
    super.key,
    required this.currentPitch,
    required this.isLanding,
    required this.touchdownVS,
    required this.touchdownPitch,
    required this.touchdownGForce,
  });

  @override
  Widget build(BuildContext context) {
    // Determine pitch limit indicators
    // Concorde tailstrike limit is 12.5 degrees pitch
    final pitchAngle = currentPitch.clamp(-10.0, 20.0);
    final pitchRatio = (pitchAngle + 10.0) / 30.0; // Map -10 to +20 degrees

    return EfbGlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HIGH ALPHA PITCH MONITOR',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Pitch gauge
                Row(
                  children: [
                    // Vertical visual gauge
                    Container(
                      width: 14,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.24),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          // Tailstrike danger zone marking (top part of gauge, > 12 deg)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 120 * (8 / 30.0), // Pitch 12 to 20
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.2),
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(7),
                                  topRight: Radius.circular(7),
                                ),
                              ),
                            ),
                          ),
                          // Moving pitch indicator dot
                          Positioned(
                            bottom: (120 * pitchRatio).clamp(0.0, 114.0),
                            left: 1,
                            right: 1,
                            height: 6,
                            child: Container(
                              decoration: BoxDecoration(
                                color: currentPitch >= 12.0 ? Colors.redAccent : Colors.greenAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'CURRENT PITCH',
                            style: GoogleFonts.plusJakartaSans(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white30),
                          ),
                          Text(
                            '${currentPitch.toStringAsFixed(1)}°',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: currentPitch >= 12.0 ? Colors.redAccent : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            currentPitch >= 12.0
                                ? 'CRITICAL TAILSTRIKE ZONE'
                                : currentPitch >= 10.0
                                    ? 'CAUTION: HIGH ALPHA APPROACH'
                                    : 'SAFE TAIL CLEARANCE',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: currentPitch >= 12.0
                                  ? Colors.redAccent
                                  : currentPitch >= 10.0
                                      ? Colors.amberAccent
                                      : Colors.white30,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // Touchdown overlay score card
            if (isLanding)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.95), // Translucent slate backdrop
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: touchdownPitch >= 12.0 ? Colors.redAccent : Colors.white10,
                      width: 1.5,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'TOUCHDOWN REPORT',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildReportItem(
                            'RATE',
                            '${touchdownVS.round()} FPM',
                            _getVsColor(touchdownVS),
                          ),
                          _buildReportItem(
                            'PITCH',
                            '${touchdownPitch.toStringAsFixed(1)}°',
                            touchdownPitch >= 12.0 ? Colors.redAccent : Colors.greenAccent,
                          ),
                          _buildReportItem(
                            'G-FORCE',
                            '${touchdownGForce.toStringAsFixed(2)} G',
                            touchdownGForce > 2.0 ? Colors.redAccent : Colors.greenAccent,
                          ),
                        ],
                      ),
                      if (touchdownPitch >= 12.0) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'WARNING: TAILSTRIKE RISK BREACHED',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getVsColor(double vs) {
    final absVs = vs.abs();
    if (absVs <= 250) return Colors.greenAccent;
    if (absVs <= 500) return Colors.amberAccent;
    return Colors.redAccent;
  }

  Widget _buildReportItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(fontSize: 8, color: Colors.white30, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.jetBrainsMono(fontSize: 14, color: color, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
