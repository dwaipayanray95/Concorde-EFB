import 'package:flutter/material.dart';
import '../../../data/models/telemetry_model.dart';
import 'lcd_theme.dart';
import 'lcd_shell.dart';

/// 09 // REHEAT & ICING STATUS
class ReheatIcingModule extends StatelessWidget {
  final TelemetryModel t;
  final bool isConnected;
  final bool anyReheat;

  const ReheatIcingModule({super.key, required this.t, required this.isConnected, required this.anyReheat});

  @override
  Widget build(BuildContext context) {
    final tat = isConnected ? t.tat : 15.0;
    // Icing risk: TAT between -40 and +2 °C is the classic airframe icing envelope
    final icingRisk = isConnected && tat >= -40.0 && tat <= 2.0;

    return LcdModulePanel(
      title: '09 // REHEAT & ICING STATUS',
      tag: 'SAFETY',
      tagColor: lcdAmber,
      child: Column(
        children: [
          // 4 reheat indicators
          Text('OLYMPUS 593 AFTERBURNER STATUS', style: lcdLabel(size: 8)),
          const SizedBox(height: 8),
          Row(
            children: List.generate(4, (i) {
              final active = isConnected && t.reheatActive.length > i && t.reheatActive[i];
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? Colors.orangeAccent.withValues(alpha: 0.1) : lcdBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? Colors.orangeAccent.withValues(alpha: 0.5) : lcdBorder,
                      width: active ? 1.5 : 1.0,
                    ),
                    boxShadow: active ? [const BoxShadow(color: Colors.orangeAccent, blurRadius: 12, spreadRadius: -2)] : null,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 20,
                        color: active ? Colors.orangeAccent : lcdMuted,
                      ),
                      const SizedBox(height: 4),
                      Text('ENG\n${i + 1}', textAlign: TextAlign.center, style: lcdLabel(size: 8, color: active ? Colors.orangeAccent : lcdMuted)),
                      const SizedBox(height: 2),
                      Text(
                        active ? 'ON' : 'OFF',
                        style: lcdMono(size: 9, color: active ? Colors.orangeAccent : lcdMuted),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),

          // Icing detection
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: icingRisk
                  ? Colors.blueAccent.withValues(alpha: 0.08)
                  : Colors.greenAccent.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: icingRisk
                    ? Colors.blueAccent.withValues(alpha: 0.35)
                    : Colors.greenAccent.withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.ac_unit,
                  size: 18,
                  color: icingRisk ? Colors.blueAccent : Colors.greenAccent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ICING RISK ENVELOPE', style: lcdLabel(size: 9)),
                      Text(
                        icingRisk
                            ? 'WARNING: TAT ${tat.round()}°C — ICING CONDITIONS'
                            : 'CLEAR — TAT ${tat.round()}°C  (safe)',
                        style: lcdMono(size: 9, color: icingRisk ? Colors.blueAccent : Colors.greenAccent),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          lcdInfoCell(
            'REHEAT SUMMARY',
            anyReheat ? '${t.reheatActive.where((v) => v).length}/4 ACTIVE' : 'ALL OFF',
            anyReheat ? Colors.orangeAccent : Colors.white70,
          ),
        ],
      ),
    );
  }
}
