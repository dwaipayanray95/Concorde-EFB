import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/telemetry_model.dart';
import 'telemetry_provider.dart';

/// Which checklist phase the aircraft is in right now, from live sim data
/// (null when the sim isn't connected). Ids match `checklistPhases` in
/// lib/data/checklist_data.dart.
///
/// Remembers whether the aircraft has been airborne (and above 10,000 ft)
/// this session, so taxi-in reads as "landing" rather than "before takeoff",
/// and a descent below 10,000 ft reads as "approach" rather than "after
/// takeoff".
class LiveChecklistPhaseNotifier extends Notifier<String?> {
  bool _airborneSeen = false;
  bool _highSeen = false;

  @override
  String? build() {
    ref.listen(flightMonitorProvider, (_, next) {
      final phase = _phaseOf(next);
      if (phase != state) state = phase;
    });
    return _phaseOf(ref.read(flightMonitorProvider));
  }

  String? _phaseOf(FlightMonitorState s) {
    final t = s.currentTelemetry;
    return t == null
        ? null
        : _phaseFor(t, s.smoothedFuelFlowKgH ?? t.fuelBurnTotal);
  }

  String _phaseFor(TelemetryModel t, double fuelFlowKgH) {
    if (t.onGround) {
      if (_airborneSeen) return 'landing';
      if (fuelFlowKgH < 800) return 'cold_dark'; // engines not running
      if (t.gs < 3) return 'before_start';
      return 'before_takeoff';
    }
    _airborneSeen = true;
    if (t.altitude > 10000) _highSeen = true;

    final descending = t.vs < -500;
    if (t.mach >= 0.95 || (t.altitude >= 25000 && !descending)) {
      return 'cruise_accel';
    }
    if (descending && t.altitude >= 10000) return 'descent';
    if (_highSeen && t.altitude < 10000) {
      return t.gearLabel == 'DOWN' ? 'landing' : 'approach';
    }
    return 'after_takeoff';
  }
}

final liveChecklistPhaseProvider =
    NotifierProvider<LiveChecklistPhaseNotifier, String?>(
      LiveChecklistPhaseNotifier.new,
    );
