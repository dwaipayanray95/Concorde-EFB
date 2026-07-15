import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:concorde_efb/providers/efb_providers.dart';
import '../../data/models/telemetry_model.dart';
import 'lcd/lcd_theme.dart';
import 'lcd/lcd_alert_bar.dart';
import 'lcd/pfd_module.dart';
import 'lcd/airspeed_module.dart';
import 'lcd/altimeter_module.dart';
import 'lcd/compass_module.dart';
import 'lcd/eicas_module.dart';
import 'lcd/fuel_module.dart';
import 'lcd/systems_module.dart';
import 'lcd/droop_gear_module.dart';
import 'lcd/reheat_icing_module.dart';
import 'lcd/endurance_module.dart';

/// Root Concorde glass-cockpit avionics panel. Lays out the ten LCD modules
/// (defined under presentation/widgets/lcd/) in a fixed 3-row grid and
/// derives the master-caution annunciations shown in the top alert bar.
class ConcordeLcdPanel extends ConsumerWidget {
  final TelemetryModel telemetry;
  final bool isConnected;

  const ConcordeLcdPanel({
    super.key,
    required this.telemetry,
    required this.isConnected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = telemetry;

    // Derived values
    final bool anyReheat = t.reheatActive.any((v) => v);
    final bool cgWarning = t.cgPct < t.cgFwdLimit || t.cgPct > t.cgAftLimit;
    final bool overspeed = t.ias > 380 || t.mach > 2.04;
    final bool slowSpeed = t.ias < 150 && t.altitude > 1000;
    final bool tempWarn = t.tat >= 121.0;
    final bool tempCrit = t.tat >= 127.0;

    // Annunciations
    final List<LcdAlert> alerts = [
      if (overspeed) const LcdAlert('OVERSPEED EXCEEDANCE', lcdRed),
      if (slowSpeed) const LcdAlert('LOW IAS / STALL RISK', lcdRed),
      if (tempCrit) const LcdAlert('NOSE TEMP CRITICAL >127°C', lcdRed),
      if (tempWarn && !tempCrit) const LcdAlert('NOSE TEMP WARNING >121°C', lcdAmber),
      if (cgWarning) const LcdAlert('CG LIMIT EXCEEDANCE', Colors.orangeAccent),
      if (!isConnected) const LcdAlert('SIMCONNECT DISCONNECTED', Colors.blueAccent),
    ];

    final fuelBreakdown = ref.watch(fuelBreakdownProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Top annunciator bar ──────────────────────────────────────────
        LcdAlertBar(alerts: alerts, isConnected: isConnected, zuluTime: t.zuluTime),
        const SizedBox(height: 12),

        // ── Main grid (flat — parent scroll view handles scrolling) ──────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: PFD | Airspeed | Altimeter/VSI | Compass
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: PfdModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: AirspeedModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: AltimeterModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 3, child: CompassModule(t: t, isConnected: isConnected)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Row 2: EICAS × 4 engines | Fuel | CG+Thermal
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 5, child: EicasModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: FuelModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: SystemsModule(t: t, isConnected: isConnected, cgWarning: cgWarning, tempWarn: tempWarn, tempCrit: tempCrit)),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Row 3: Concorde-specific extras
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(flex: 4, child: ConcordeDroopGearModule(t: t, isConnected: isConnected)),
                    const SizedBox(width: 10),
                    Expanded(flex: 4, child: ReheatIcingModule(t: t, isConnected: isConnected, anyReheat: anyReheat)),
                    const SizedBox(width: 10),
                    Expanded(flex: 5, child: EnduranceModule(t: t, isConnected: isConnected, fuelBreakdown: fuelBreakdown)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ],
    );
  }
}
