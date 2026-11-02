import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/concorde_logic.dart';
import '../../../models/airport.dart';
import '../../../providers/efb_providers.dart';
import '../../flight_monitor/presentation/controllers/live_alerts_provider.dart';
import '../../flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../../flight_monitor/data/models/telemetry_model.dart';
import '../data/flight_log.dart';
import '../data/logbook_repository.dart';
import '../domain/flight_tracker.dart';

final logbookRepositoryProvider = Provider((ref) => LogbookRepository());

/// Flight logging runs on desktop only (the sim PC); tests override this.
final loggingEnabledProvider = Provider<bool>(
  (ref) => const {
    TargetPlatform.windows,
    TargetPlatform.macOS,
    TargetPlatform.linux,
  }.contains(defaultTargetPlatform),
);

class LogbookNotifier extends AsyncNotifier<List<FlightLog>> {
  LogbookRepository get _repo => ref.read(logbookRepositoryProvider);

  @override
  Future<List<FlightLog>> build() {
    if (ref.watch(loggingEnabledProvider)) _watchDir();
    return _repo.list();
  }

  /// Desktop: the bridge writes logs the phone edited straight into the
  /// folder, so pick those up (debounced). Best effort -- watch() can throw
  /// or be unsupported on some filesystems.
  void _watchDir() {
    StreamSubscription<FileSystemEvent>? sub;
    Timer? debounce;
    ref.onDispose(() {
      debounce?.cancel();
      sub?.cancel();
    });
    () async {
      try {
        final dir = await _repo.directory();
        if (!ref.mounted) return;
        sub = dir.watch().listen((_) {
          debounce?.cancel();
          debounce = Timer(const Duration(milliseconds: 500), () {
            if (ref.mounted) unawaited(refresh());
          });
        }, onError: (_) {});
      } catch (_) {}
    }();
  }

  Future<void> refresh() async => state = AsyncData(await _repo.list());

  Future<void> upsert(FlightLog log) async {
    await _repo.save(log);
    final all = [
      log,
      for (final l in state.value ?? const <FlightLog>[])
        if (l.id != log.id) l,
    ]..sort((a, b) => b.blockOut.compareTo(a.blockOut));
    state = AsyncData(all);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    state = AsyncData([
      for (final l in state.value ?? const <FlightLog>[])
        if (l.id != id) l,
    ]);
  }

  Future<void> setNotes(String id, String notes) async {
    final log = state.value?.where((l) => l.id == id).firstOrNull;
    if (log == null) return;
    await upsert(log.copyWith(notes: notes, updatedAt: DateTime.now().toUtc()));
  }
}

final logbookProvider = AsyncNotifierProvider<LogbookNotifier, List<FlightLog>>(
  LogbookNotifier.new,
);

/// Feeds live telemetry to a [FlightTracker] and saves the log at each
/// milestone, so a crash never loses a flight. State = latest touchdown
/// (for a future UI pill); null until one happens / after a go-around.
class FlightTrackerNotifier extends Notifier<FlightLog?> {
  final _tracker = FlightTracker();

  @override
  FlightLog? build() {
    if (!ref.watch(loggingEnabledProvider)) return null;
    ref.listen(flightMonitorProvider, (_, next) {
      final t = next.currentTelemetry;
      if (t != null) _feed(t);
    });
    return null;
  }

  void _feed(TelemetryModel t) {
    final ev = _tracker.update(t, DateTime.now().toUtc(), _context(t));
    final log = _tracker.current;
    if (ev == null || log == null) return;
    if (ev == TrackerEvent.touchdown) state = log;
    if (ev == TrackerEvent.goAround) state = null;
    if (ev != TrackerEvent.discarded) {
      unawaited(ref.read(logbookProvider.notifier).upsert(log));
    }
  }

  TrackerContext _context(TelemetryModel t) {
    final db = ref.read(airportDbProvider).value;
    final mission = ref.read(missionProfileProvider);
    return TrackerContext(
      callSign: ref.read(callSignProvider),
      registration: ref.read(registrationProvider),
      plannedDep: ref.read(departureIcaoProvider),
      plannedArr: ref.read(arrivalIcaoProvider),
      alternate: ref.read(alternateIcaoProvider),
      planSource: ref.read(flightPlanSourceProvider).name,
      plannedTimeH: mission.totalTimeH,
      plannedTripKg: mission.tripKg,
      cruiseFl: ref.read(cruiseFLProvider),
      finalReserveKg: ref.read(fuelBreakdownProvider).finalReserveKg,
      zfwKg: ref.read(weightsProvider).zfw,
      alertTexts: [for (final a in ref.read(liveAlertsProvider)) a.text],
      nearestAirport: (lat, lon) {
        String? best;
        var bestNm = 10.0;
        for (final a in db?.airports.values ?? const <Airport>[]) {
          if ((a.lat - lat).abs() > 0.5) continue;
          final nm = ConcordeLogic.greatCircleNM(lat, lon, a.lat, a.lon);
          if (nm < bestNm) {
            bestNm = nm;
            best = a.icao;
          }
        }
        return best;
      },
    );
  }
}

final flightTrackerProvider =
    NotifierProvider<FlightTrackerNotifier, FlightLog?>(
      FlightTrackerNotifier.new,
    );
