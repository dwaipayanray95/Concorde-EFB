import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:concorde_efb/widgets/efb_glass_container.dart';

class CgEnvelopeWidget extends StatelessWidget {
  final double mach;
  final double cgPct;

  const CgEnvelopeWidget({
    super.key,
    required this.mach,
    required this.cgPct,
  });

  double getFwdLimit(double m) {
    if (m <= 0.93) return 52.0;
    if (m >= 1.6) return 55.0;
    final t = (m - 0.93) / (1.6 - 0.93);
    return 52.0 + t * (55.0 - 52.0);
  }

  double getAftLimit(double m) {
    if (m <= 0.93) return 54.0;
    if (m >= 1.6) return 59.0;
    final t = (m - 0.93) / (1.6 - 0.93);
    return 54.0 + t * (59.0 - 54.0);
  }

  @override
  Widget build(BuildContext context) {
    final fwd = getFwdLimit(mach);
    final aft = getAftLimit(mach);
    final isOut = cgPct < fwd || cgPct > aft;

    Color borderColor = Colors.white10;
    Color glowColor = Colors.transparent;
    Color textColor = Colors.white;

    if (isOut) {
      borderColor = Colors.redAccent.withValues(alpha: 0.5);
      glowColor = Colors.redAccent.withValues(alpha: 0.15);
      textColor = Colors.redAccent;
    } else if (cgPct < fwd + 0.5 || cgPct > aft - 0.5) {
      borderColor = Colors.amberAccent.withValues(alpha: 0.5);
      glowColor = Colors.amberAccent.withValues(alpha: 0.1);
      textColor = Colors.amberAccent;
    }

    return EfbGlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [
        if (glowColor != Colors.transparent)
          BoxShadow(color: glowColor, blurRadius: 20, spreadRadius: 0),
      ],
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CG ENVELOPE LIMITS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'CG: ${cgPct.toStringAsFixed(1)}% (Limits: ${fwd.toStringAsFixed(1)}% - ${aft.toStringAsFixed(1)}%)',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  minX: 0.0,
                  maxX: 2.2,
                  minY: 50.0,
                  maxY: 62.0,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 2,
                    verticalInterval: 0.5,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                    getDrawingVerticalLine: (value) => FlLine(
                      color: Colors.white.withValues(alpha: 0.05),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Text(
                        'MACH SPEED',
                        style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, meta) => Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            val.toStringAsFixed(1),
                            style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white30),
                          ),
                        ),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      axisNameWidget: Text(
                        'CG %',
                        style: GoogleFonts.plusJakartaSans(fontSize: 9, color: Colors.white30, fontWeight: FontWeight.bold),
                      ),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (val, meta) => Padding(
                          padding: const EdgeInsets.only(right: 4.0),
                          child: Text(
                            '${val.toInt()}%',
                            style: GoogleFonts.jetBrainsMono(fontSize: 8, color: Colors.white30),
                          ),
                        ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  lineBarsData: [
                    // Forward Limit Line
                    LineChartBarData(
                      spots: [
                        const FlSpot(0.0, 52.0),
                        const FlSpot(0.93, 52.0),
                        const FlSpot(1.2, 53.0),
                        const FlSpot(1.6, 55.0),
                        const FlSpot(2.2, 55.0),
                      ],
                      isCurved: false,
                      color: Colors.blueAccent.withValues(alpha: 0.7),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    // Aft Limit Line
                    LineChartBarData(
                      spots: [
                        const FlSpot(0.0, 54.0),
                        const FlSpot(0.93, 54.0),
                        const FlSpot(1.2, 57.0),
                        const FlSpot(1.6, 59.0),
                        const FlSpot(2.2, 59.0),
                      ],
                      isCurved: false,
                      color: Colors.orangeAccent.withValues(alpha: 0.7),
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                    ),
                    // Current position dot
                    LineChartBarData(
                      spots: [FlSpot(mach.clamp(0.0, 2.2), cgPct.clamp(50.0, 62.0))],
                      isCurved: false,
                      color: isOut ? Colors.redAccent : Colors.greenAccent,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 6,
                          color: isOut ? Colors.red : Colors.greenAccent,
                          strokeColor: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
