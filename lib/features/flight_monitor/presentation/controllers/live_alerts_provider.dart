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

const descendNowText = 'DESCEND NOW';
const gearCheckText = 'GEAR UP — CHECK GEAR';
const gearWarningText = 'GEAR UP — TOO LOW';

/// Alerts the pilot cleared (tap on the MFD strip) because ATC, the
/// charts/procedure or terrain dictate otherwise. Cleared alerts are hidden
/// and silent until they re-arm:
///  - DESCEND NOW: once the aircraft leaves cruise (descent / new flight);
///  - gear alerts: once the gear goes down or the aircraft climbs away.
class DismissedAlertsNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.listen(liveNavProvider.select((n) => n?.phase), (_, phase) {
      if (phase != FlightBurnPhase.cruise) _rearm({descendNowText});
    });
    ref.listen(flightMonitorProvider.select((m) => m.currentTelemetry), (_, t) {
      if (t == null || t.gearLabel != 'UP' || t.vs > 500) {
        _rearm({gearCheckText, gearWarningText});
      }
    });
    return {};
  }

  void _rearm(Set<String> texts) {
    if (state.any(texts.contains)) {
      state = state.difference(texts);
    }
  }

  void dismiss(String text) => state = {...state, text};
}

final dismissedAlertsProvider =
    NotifierProvider<DismissedAlertsNotifier, Set<String>>(
      DismissedAlertsNotifier.new,
    );

/// Alerts that can be cleared outright (not just silenced).
const clearableAlerts = {descendNowText, gearCheckText, gearWarningText};

/// Live warnings/cautions from telemetry + the flight plan. Computed here
/// (not in a widget) so they exist -- and chime -- whichever tab is open.
/// Shown in the Flight Monitor's MFD strip.
final liveAlertsProvider = Provider<List<LiveAlert>>((ref) {
  final monitor = ref.watch(flightMonitorProvider);
  final t = monitor.currentTelemetry;
  // Sim menu / loading screen: frames arrive but no flight exists yet.
  if (t == null || !t.flightLoaded) return const [];

  final nav = ref.watch(liveNavProvider);
  final pred = nav?.prediction;
  final phase = nav?.phase ?? FlightBurnPhase.ground;
  final fuelPlan = ref.watch(fuelBreakdownProvider);
  final finalReserve = fuelPlan.finalReserveKg;
  final reservesWithAlt = finalReserve + fuelPlan.alternateKg;

  final alerts = <LiveAlert>[];
  final cg = cgLimitsForMach(t.mach);
  // CG limits are armed above 10,000 ft above the departure field: on the
  // ground and through takeoff/initial climb the CG sits at its takeoff
  // setting and the crew is still transferring fuel, so the Mach corridor
  // doesn't apply yet (owner decision).
  final moving =
      !t.onGround &&
      t.heightAboveGround(
            fieldElevationFt: ref.watch(depAirportProvider)?.elevationFt,
          ) >
          cgCorridorArmFt;
  if (moving && t.cgPct > cg.aft) {
    alerts.add(
      const LiveAlert('CG AFT LIMIT', critical: true, repeatEvery: _urgent),
    );
  }
  if (moving && t.cgPct < cg.fwd) {
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
  // Gear up while descending towards the destination. Two levels so a
  // step-down or hold far out doesn't nag:
  //  - caution (once): within 30 nm, < 5,000 ft above the airport, < 250 kt
  //    (DC Designs manual: gear lights flash below 250 kt with gear up);
  //  - warning (repeating): within 10 nm, < 2,000 ft, < 220 kt.
  // Height above the arrival airport (not sea level). Both are clearable.
  final heightAgl = t.heightAboveGround(
    fieldElevationFt: ref.watch(arrAirportProvider)?.elevationFt,
  );
  final distNm = pred?.distToDestNm;
  final dismissed = ref.watch(dismissedAlertsProvider);
  if (t.gearLabel == 'UP' && !t.onGround && t.vs < -300 && distNm != null) {
    if (distNm <= 10 && heightAgl < 2000 && t.ias < 220) {
      if (!dismissed.contains(gearWarningText)) {
        alerts.add(
          const LiveAlert(
            gearWarningText,
            critical: true,
            repeatEvery: _urgent,
          ),
        );
      }
    } else if (distNm <= 30 && heightAgl < 5000 && t.ias < 250) {
      if (!dismissed.contains(gearCheckText)) {
        alerts.add(const LiveAlert(gearCheckText, critical: false));
      }
    }
  }
  // Fuel-at-destination warnings only from cruise on: the high climb /
  // reheat burn is planned and would otherwise trip them on every takeoff.
  final cruising =
      phase == FlightBurnPhase.cruise || phase == FlightBurnPhase.descent;
  if (pred != null && cruising) {
    if (pred.fuelAtDestKg < finalReserve) {
      alerts.add(
        const LiveAlert('FUEL BELOW FINAL RESERVE AT DEST', critical: true),
      );
    } else if (pred.fuelAtDestKg < reservesWithAlt) {
      alerts.add(const LiveAlert('NO ALTERNATE FUEL AT DEST', critical: false));
    }
    if (pred.distToTodNm <= 10 &&
        pred.distToTodNm > -20 &&
        phase == FlightBurnPhase.cruise &&
        !dismissed.contains(descendNowText)) {
      alerts.add(
        const LiveAlert(
          descendNowText,
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
