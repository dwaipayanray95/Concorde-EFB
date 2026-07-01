import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ui_tokens.dart';
import 'package:concorde_efb/widgets/efb_glass_container.dart';

class ThermalPanelWidget extends StatefulWidget {
  final double tat;

  const ThermalPanelWidget({super.key, required this.tat});

  @override
  State<ThermalPanelWidget> createState() => _ThermalPanelWidgetState();
}

class _ThermalPanelWidgetState extends State<ThermalPanelWidget> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temp = widget.tat;
    Color barColor = Colors.greenAccent;
    Color glowColor = Colors.transparent;
    bool isWarning = false;
    bool isCritical = false;

    if (temp >= 127.0) {
      barColor = Colors.redAccent;
      glowColor = Colors.redAccent.withValues(alpha: 0.3);
      isCritical = true;
    } else if (temp >= 121.0) {
      barColor = Colors.amberAccent;
      glowColor = Colors.amberAccent.withValues(alpha: 0.15);
      isWarning = true;
    }

    final fillRatio = (temp.clamp(-50.0, 150.0) + 50.0) / 200.0; // Map -50..150C

    return EfbGlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        if (glowColor != Colors.transparent && (!isCritical || _blinkController.value > 0.5))
          BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 0),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCritical
                ? Colors.redAccent.withValues(alpha: _blinkController.value)
                : isWarning
                    ? Colors.amberAccent.withValues(alpha: 0.3)
                    : Colors.white10,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Vertical Thermometer Gauge
            Column(
              children: [
                Text(
                  '150°',
                  style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white30),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Container(
                    width: 12,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.24),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        FractionallySizedBox(
                          heightFactor: fillRatio.clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: barColor,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: barColor.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '-50°',
                  style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white30),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Temperature metrics and metadata
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TOTAL AIR TEMP (TAT)',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: UiTokens.textSecondary,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedBuilder(
                    animation: _blinkController,
                    builder: (context, child) {
                      final showBlink = isCritical && _blinkController.value > 0.5;
                      return Text(
                        '${temp.toStringAsFixed(1)} °C',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: showBlink ? Colors.redAccent : (isCritical ? Colors.red : (isWarning ? Colors.amberAccent : Colors.white)),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isCritical
                        ? 'CRITICAL NOSE LIMIT EXCEEDED\nREDUCE MACH SPEED IMMEDIATELY'
                        : isWarning
                            ? 'THERMAL WARNING STATE\nMONITOR AIRFRAME HEATING'
                            : 'FRAME TEMP STABLE\nNOMINAL SUPERSONIC SKIN TEMP',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                      color: isCritical
                          ? Colors.redAccent
                          : isWarning
                              ? Colors.amberAccent
                              : Colors.white30,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
