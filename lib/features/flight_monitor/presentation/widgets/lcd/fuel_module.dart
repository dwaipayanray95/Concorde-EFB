import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';

/// 06 // FUEL MANAGEMENT
class FuelModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;

  const FuelModule({super.key, required this.t, required this.isConnected});

  @override
  Widget build(BuildContext context) {
    // The model stores fill percentages 0→1; convert to indicative kg using max capacities
    final lKg = (isConnected ? t.fuelLeftTank : 0.0) * 17483.0;
    final rKg = (isConnected ? t.fuelRightTank : 0.0) * 17483.0;
    final cKg = (isConnected ? t.fuelCenterTank : 0.0) * 11793.0;
    final fwdKg = (isConnected ? t.fuelTrimForward : 0.0) * 10000.0;
    final aftKg = (isConnected ? t.fuelTrimAft : 0.0) * 5681.0;
    final total = lKg + rKg + cKg + fwdKg + aftKg;
    final imbalance = (lKg - rKg).abs();
    final burnRate = isConnected ? t.fuelBurnTotal : 0.0;
    final endurance = burnRate > 0 ? total / burnRate : 0.0;

    return LcdModulePanel(
      title: '06 // FUEL MANAGEMENT SYSTEM',
      tag: 'WEIGHT KG',
      tagColor: Colors.orangeAccent,
      child: Column(
        children: [
          // Total FOB
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: lcdCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: lcdBorder),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_gas_station, color: lcdAccent, size: 14),
                    const SizedBox(width: 6),
                    Text('FOB (FUEL ON BOARD)', style: lcdLabel(size: 9)),
                  ],
                ),
                Text(
                  '${_fmtKg(total)} KG',
                  style: lcdMono(size: 14, color: total < 5000 ? lcdRed : Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Wing tanks
          Row(
            children: [
              Expanded(child: _tankCell('L WING', lKg, 17483.0)),
              const SizedBox(width: 6),
              Expanded(child: _tankCell('R WING', rKg, 17483.0)),
            ],
          ),
          const SizedBox(height: 6),

          // Center + trim tanks
          Row(
            children: [
              Expanded(child: _tankCell('CENTER', cKg, 11793.0)),
              const SizedBox(width: 6),
              Expanded(child: _tankCell('TRIM FWD', fwdKg, 10000.0)),
              const SizedBox(width: 6),
              Expanded(child: _tankCell('TRIM AFT', aftKg, 5681.0)),
            ],
          ),
          const SizedBox(height: 8),

          // Imbalance + burn
          lcdInfoCell('IMBALANCE DELTA', '${_fmtKg(imbalance)} KG', imbalance > 500 ? lcdAmber : Colors.white70),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(child: lcdInfoCell('BURN RATE', '${burnRate.round()} KG/HR')),
              const SizedBox(width: 6),
              Expanded(child: lcdInfoCell('ENDURANCE', '${endurance.toStringAsFixed(2)} HRS', Colors.greenAccent)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tankCell(String label, double val, double cap) {
    final frac = (val / cap).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: lcdCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: lcdBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: lcdLabel(size: 7)),
          const SizedBox(height: 2),
          Text(_fmtKg(val), style: lcdMono(size: 10)),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: frac,
              backgroundColor: lcdBorder,
              valueColor: AlwaysStoppedAnimation<Color>(frac < 0.15 ? lcdRed : lcdAccent),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtKg(double v) {
    final str = v.round().toString();
    final buf = StringBuffer();
    int c = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      if (c > 0 && c % 3 == 0) buf.write(',');
      buf.write(str[i]);
      c++;
    }
    return buf.toString().split('').reversed.join();
  }
}
