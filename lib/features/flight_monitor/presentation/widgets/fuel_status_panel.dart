import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/ui_tokens.dart';
import 'package:concorde_efb/widgets/efb_glass_container.dart';

class FuelStatusPanel extends StatelessWidget {
  final double left;
  final double right;
  final double center;
  final double trimFwd;
  final double trimAft;
  final double fuelFlowKgh;

  const FuelStatusPanel({
    super.key,
    required this.left,
    required this.right,
    required this.center,
    required this.trimFwd,
    required this.trimAft,
    required this.fuelFlowKgh,
  });

  @override
  Widget build(BuildContext context) {
    // Capacities mapping to Concorde's total 95,681 kg capacity
    final leftKg = left * 30000.0 / 100.0;
    final rightKg = right * 30000.0 / 100.0;
    final centerKg = center * 20000.0 / 100.0;
    final trimFwdKg = trimFwd * 10000.0 / 100.0;
    final trimAftKg = trimAft * 5681.0 / 100.0;
    
    final totalKg = leftKg + rightKg + centerKg + trimFwdKg + trimAftKg;

    return EfbGlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10, width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fuel Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FUEL STATUS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                Text(
                  'TOTAL: ${totalKg.round()} kg',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: UiTokens.accent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fuel Tanks Grid
            _buildTankRow('LEFT MAIN', left, leftKg),
            const SizedBox(height: 8),
            _buildTankRow('RIGHT MAIN', right, rightKg),
            const SizedBox(height: 8),
            _buildTankRow('CENTER MAIN', center, centerKg),
            const SizedBox(height: 8),
            _buildTankRow('TRIM FWD (9/10)', trimFwd, trimFwdKg),
            const SizedBox(height: 8),
            _buildTankRow('TRIM AFT (11)', trimAft, trimAftKg),
            
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),

            // Fuel Flow
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'FUEL FLOW / BURN RATE',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: UiTokens.textSecondary,
                  ),
                ),
                Text(
                  '${fuelFlowKgh.round()} kg/h',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Colors.amberAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTankRow(String name, double pct, double kg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.plusJakartaSans(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white60),
            ),
            Text(
              '${pct.toStringAsFixed(0)}% (${kg.round()} kg)',
              style: GoogleFonts.jetBrainsMono(fontSize: 9, color: Colors.white54),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          height: 8,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.24),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                widthFactor: (pct / 100.0).clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: pct < 15.0 ? Colors.redAccent : Colors.blueAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
