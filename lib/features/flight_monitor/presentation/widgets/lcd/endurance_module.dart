import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import '../../../../../models/concorde_models.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';

/// 10 // ENDURANCE CALCULATOR
class EnduranceModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;
  final BlockFuelBreakdown? fuelBreakdown;

  const EnduranceModule({super.key, required this.t, required this.isConnected, required this.fuelBreakdown});

  @override
  Widget build(BuildContext context) {
    final totalFuelKg = isConnected
        ? (t.fuelLeftTank * 17483 + t.fuelRightTank * 17483 + t.fuelCenterTank * 11793 +
              t.fuelTrimForward * 10000 + t.fuelTrimAft * 5681)
        : 0.0;
    final burnRate = isConnected ? t.fuelBurnTotal : 0.0;
    final alt = isConnected ? t.altitude : 0.0;
    final mach = isConnected ? t.mach : 0.0;
    final vs = isConnected ? t.vs : 0.0;

    // Phase detection
    String phase = 'Subsonic';
    double phaseRate = 12000;
    if (mach >= 2.0 && alt >= 50000) {
      phase = 'Mach 2.0 Cruise';
      phaseRate = 21500;
    } else if (mach >= 1.0) {
      phase = 'Supersonic';
      phaseRate = 24000;
    } else if (vs > 500) {
      phase = 'Climb / Accel';
      phaseRate = 28000;
    } else if (vs < -500) {
      phase = 'Descent';
      phaseRate = 5000;
    }

    final phaseEndurance = burnRate > 0 ? totalFuelKg / burnRate : totalFuelKg / phaseRate;
    final subsonicEndurance = totalFuelKg / 12000;
    final holdingEndurance = totalFuelKg / 6000;

    final reservesKg = fuelBreakdown != null
        ? (fuelBreakdown!.finalReserveKg + fuelBreakdown!.alternateKg + fuelBreakdown!.contingencyKg)
        : 0.0;
    final isLowFuel = reservesKg > 0 && totalFuelKg < reservesKg;

    return LcdModulePanel(
      title: '10 // PROFILE ENDURANCE CALCULATOR',
      tag: 'FMS PROJECTION',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Primary adaptive readout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: lcdCard,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLowFuel ? lcdRed.withValues(alpha: 0.3) : Colors.greenAccent.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ADAPTIVE ENDURANCE', style: lcdLabel(size: 9)),
                    Text('Phase: $phase', style: lcdMono(size: 8, color: lcdAccent.withValues(alpha: 0.7))),
                  ],
                ),
                Text(
                  '${phaseEndurance.toStringAsFixed(2)} HRS',
                  style: lcdMono(size: 22, color: isLowFuel ? lcdRed : Colors.greenAccent),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          _enduranceRow('Subsonic Escape Range', subsonicEndurance, '12,000 kg/hr'),
          const SizedBox(height: 6),
          _enduranceRow('Max Holding Pattern', holdingEndurance, '6,000 kg/hr'),
          const SizedBox(height: 8),

          if (isLowFuel)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: lcdRed.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: lcdRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: lcdRed, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'FUEL BELOW PLANNED RESERVES',
                      style: lcdMono(size: 9, color: lcdRed),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _enduranceRow(String label, double hrs, String burnNote) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: lcdLabel(size: 9)),
            Text(burnNote, style: lcdMono(size: 7, color: lcdMuted, weight: FontWeight.normal)),
          ],
        ),
        Text('${hrs.toStringAsFixed(2)} hrs', style: lcdMono(size: 12, color: Colors.white)),
      ],
    );
  }
}
