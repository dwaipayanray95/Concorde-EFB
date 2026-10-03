import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/concorde_constants.dart';
import '../../../../core/live_flight_math.dart';
import '../../../../models/concorde_models.dart';
import '../../../../providers/efb_providers.dart';
import 'live_nav_provider.dart';
import 'telemetry_provider.dart';

/// One live annunciator. [critical] = red warning, otherwise amber caution.
class LiveAlert {
  final String text;
  final bool critical;

  /// Re-chime interval while the alert stays active; null = chime once.
  final Duration? repeatEvery;
  const LiveAlert(this.text, {required this.critical, this.repeatEvery});
}

/// Immediate-action warnings re-chime every 2 s until cleared.
const _urgent = Duration(seconds: 2);

/// DESCEND NOW re-chimes every 12 s until the descent starts.
const _descendReminder = Duration(seconds: 12);

/// Live warnings/cautions from telemetry + the flight plan. Computed here
/// (not in a widget) so they exist -- and chime -- whichever tab is open.
/// Shown in the Flight Monitor's MFD strip.
final liveAlertsProvider = Provider<List<LiveAlert>>((ref) {
  final monitor = ref.watch(flightMonitorProvider);
  final t = monitor.currentTelemetry;
  if (t == null) return const [];

  final nav = ref.watch(liveNavProvider);
  final pred = nav?.prediction;
  final phase = nav?.phase ?? FlightBurnPhase.ground;
  final fuelPlan = ref.watch(fuelBreakdownProvider);
  final finalReserve = fuelPlan.finalReserveKg;
  final reservesWithAlt = finalReserve + fuelPlan.alternateKg;

  final alerts = <LiveAlert>[];
  final cg = cgLimitsForMach(t.mach);
  if (t.cgPct > cg.aft) {
    alerts.add(
      const LiveAlert('CG AFT LIMIT', critical: true, repeatEvery: _urgent),
    );
  }
  if (t.cgPct < cg.fwd) {
    alerts.add(
      const LiveAlert('CG FWD LIMIT', critical: true, repeatEvery: _urgent),
    );
  }
  if (t.mach > ConcordeConstants.speeds.mmo) {
    alerts.add(
      const LiveAlert('MACH > MMO', critical: true, repeatEvery: _urgent),
    );
  }
  if (t.gearLabel != 'UP' &&
      !t.onGround &&
      t.ias > ConcordeConstants.speeds.vleKt) {
    alerts.add(
      const LiveAlert('GEAR SPEED', critical: true, repeatEvery: _urgent),
    );
  }
  // DC Designs manual: gear lights flash red below 250 kt IAS with the gear
  // up -- i.e. low and slow on approach without the gear down (below 5,000
  // ft above the ground).
  // Height above the ground (not sea level), so it works at high airports.
  final heightAgl = t.heightAboveGround(
    fieldElevationFt: ref.watch(arrAirportProvider)?.elevationFt,
  );
  if (t.gearLabel == 'UP' &&
      !t.onGround &&
      t.ias < 250 &&
      t.vs < -300 &&
      heightAgl < 5000) {
    alerts.add(
      const LiveAlert(
        'GEAR UP — BELOW 250 KT',
        critical: true,
        repeatEvery: _urgent,
      ),
    );
  }
  if (pred != null && phase != FlightBurnPhase.ground) {
    if (pred.fuelAtDestKg < finalReserve) {
      alerts.add(
        const LiveAlert('FUEL BELOW FINAL RESERVE AT DEST', critical: true),
      );
    } else if (pred.fuelAtDestKg < reservesWithAlt) {
      alerts.add(const LiveAlert('NO ALTERNATE FUEL AT DEST', critical: false));
    }
    if (pred.distToTodNm <= 10 &&
        pred.distToTodNm > -20 &&
        phase == FlightBurnPhase.cruise) {
      alerts.add(
        const LiveAlert(
          'DESCEND NOW',
          critical: false,
          repeatEvery: _descendReminder,
        ),
      );
    }
  }
  if (ref.watch(arrAirportProvider) == null) {
    alerts.add(const LiveAlert('NO DESTINATION IN PLAN', critical: false));
  }
  return alerts;
});
