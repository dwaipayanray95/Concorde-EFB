import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';

/// 07 // SYSTEMS — CG & Thermal
class SystemsModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;
  final bool cgWarning;
  final bool tempWarn;
  final bool tempCrit;

  const SystemsModule({
    super.key,
    required this.t,
    required this.isConnected,
    required this.cgWarning,
    required this.tempWarn,
    required this.tempCrit,
  });

  @override
  Widget build(BuildContext context) {
    final cg = isConnected ? t.cgPct : 53.5;
    final tat = isConnected ? t.tat : 15.0;
    final fwdLim = isConnected ? t.cgFwdLimit : 52.0;
    final aftLim = isConnected ? t.cgAftLimit : 59.0;

    // CG bar position 50%→65% range mapped to bar width
    final cgNorm = ((cg - 50.0) / 15.0).clamp(0.0, 1.0);
    final fwdNorm = ((fwdLim - 50.0) / 15.0).clamp(0.0, 1.0);
    final aftNorm = ((aftLim - 50.0) / 15.0).clamp(0.0, 1.0);

    return LcdModulePanel(
      title: '07 // CG & THERMAL SYSTEMS',
      tag: 'OP-SAFETY',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // CG section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CG POSITION', style: lcdLabel(size: 9)),
                  Text('FWD ${fwdLim.toStringAsFixed(1)}% — AFT ${aftLim.toStringAsFixed(1)}%', style: lcdLabel(size: 7, color: lcdMuted)),
                ],
              ),
              Text(
                '${cg.toStringAsFixed(1)}%',
                style: lcdMono(size: 18, color: cgWarning ? lcdRed : Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // CG bar with limit markers
          Stack(
            children: [
              Container(
                height: 12,
                decoration: BoxDecoration(
                  color: lcdCard,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: lcdBorder),
                ),
              ),
              // Safe zone highlight
              Positioned(
                left: MediaQuery.sizeOf(context).width * 0.0 + fwdNorm * 100,
                width: (aftNorm - fwdNorm) * 100,
                top: 2,
                bottom: 2,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // CG pointer
              Align(
                alignment: Alignment(cgNorm * 2 - 1, 0),
                child: Container(
                  width: 3,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cgWarning ? lcdRed : lcdAccent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [BoxShadow(color: (cgWarning ? lcdRed : lcdAccent).withValues(alpha: 0.5), blurRadius: 4)],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // TAT section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('TOTAL AIR TEMP (TAT)', style: lcdLabel(size: 9)),
                  Text('NOSE STRUCTURAL LIMIT: 127°C', style: lcdLabel(size: 7, color: lcdMuted)),
                ],
              ),
              Text(
                '${tat.round()}°C',
                style: lcdMono(
                  size: 18,
                  color: tempCrit ? lcdRed : tempWarn ? lcdAmber : Colors.greenAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (tat / 150.0).clamp(0.0, 1.0),
              backgroundColor: lcdBg,
              valueColor: AlwaysStoppedAnimation<Color>(
                tempCrit ? lcdRed : tempWarn ? lcdAmber : Colors.greenAccent,
              ),
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
