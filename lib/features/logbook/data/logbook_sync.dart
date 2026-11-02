import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../flight_monitor/data/services/lan_link.dart';
import '../../flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../presentation/logbook_providers.dart';
import 'flight_log.dart';

/// What to do to bring the phone's logbook in line with the desktop's.
class SyncPlan {
  final List<String> toFetch;
  final List<String> toPush;
  final List<String> toDeleteLocal;
  final List<String> toDeleteRemote;
  const SyncPlan({
    this.toFetch = const [],
    this.toPush = const [],
    this.toDeleteLocal = const [],
    this.toDeleteRemote = const [],
  });
}

/// Pure sync decision. [local] and [remote] map id -> `updatedAt` (ISO).
/// The desktop is the master: ids it lacks are dropped locally, missing or
/// newer ids are fetched, and only a strictly newer local copy (a notes edit
/// made on the phone) is pushed. [pendingDeletes] are phone-side deletions
/// not yet delivered: they are removed on the desktop instead of re-fetched.
SyncPlan planLogbookSync({
  required Map<String, String> local,
  required Map<String, String> remote,
  Set<String> pendingDeletes = const {},
}) {
  int cmp(String a, String b) {
    final da = DateTime.tryParse(a), db = DateTime.tryParse(b);
    return da != null && db != null ? da.compareTo(db) : a.compareTo(b);
  }

  final fetch = <String>[], push = <String>[], delLocal = <String>[];
  final delRemote = <String>[];
  for (final e in remote.entries) {
    if (pendingDeletes.contains(e.key)) {
      delRemote.add(e.key);
      continue;
    }
    final mine = local[e.key];
    if (mine == null) {
      fetch.add(e.key);
    } else {
      final c = cmp(e.value, mine);
      if (c > 0) fetch.add(e.key);
      if (c < 0) push.add(e.key);
    }
  }
  for (final id in local.keys) {
    if (!remote.containsKey(id)) delLocal.add(id);
  }
  return SyncPlan(
    toFetch: fetch,
    toPush: push,
    toDeleteLocal: delLocal,
    toDeleteRemote: delRemote,
  );
}

class LogbookSyncState {
  final bool connected;
  final DateTime? lastSync;
  const LogbookSyncState({this.connected = false, this.lastSync});
}

/// Phone/tablet only: mirrors the desktop logbook over the bridge socket.
/// Idle on desktop. Keep it watched (HomeScreen) so it runs on every tab.
class LogbookSyncNotifier extends Notifier<LogbookSyncState> {
  static const _interval = Duration(seconds: 60);

  final _pendingDeletes = <String>{};
  final _selfRemoved = <String>{};
  Set<String> _knownIds = {};
  DateTime? _lastSync;

  @override
  LogbookSyncState build() {
    if (!isMobilePlatform) return const LogbookSyncState();
    final connected = ref.watch(
      flightMonitorProvider.select((s) => s.bridge.socketConnected),
    );
    if (!connected) return LogbookSyncState(lastSync: _lastSync);

    final monitor = ref.read(flightMonitorProvider.notifier);
    final sub = monitor.logbookMessages.listen(_onMessage);
    final timer = Timer.periodic(_interval, (_) => _requestIndex());
    Timer? debounce;
    ref.listen(logbookProvider, (prev, next) {
      final ids = {for (final l in next.value ?? const <FlightLog>[]) l.id};
      final removed = _knownIds.difference(ids)..removeAll(_selfRemoved);
      _selfRemoved.removeAll(_knownIds.difference(ids));
      _knownIds = ids;
      for (final id in removed) {
        _pendingDeletes.add(id);
        monitor.sendJson({'type': 'logbook_delete', 'id': id});
      }
      debounce?.cancel();
      debounce = Timer(const Duration(seconds: 1), _requestIndex);
    });
    ref.onDispose(() {
      sub.cancel();
      timer.cancel();
      debounce?.cancel();
    });
    _knownIds = {
      for (final l in ref.read(logbookProvider).value ?? const <FlightLog>[])
        l.id,
    };
    _requestIndex();
    return LogbookSyncState(connected: true, lastSync: _lastSync);
  }

  void _requestIndex() {
    ref.read(flightMonitorProvider.notifier).sendJson({
      'type': 'logbook_index',
    });
  }

  Future<void> _onMessage(Map<String, dynamic> m) async {
    try {
      switch (m['type']) {
        case 'logbook_index':
          await _onIndex(m);
        case 'logbook_entry':
          await _onEntry(m);
        case 'logbook_ack':
          _pendingDeletes.remove(m['id']);
      }
    } catch (e) {
      debugPrint('Logbook sync: $e');
    }
  }

  Future<void> _onIndex(Map<String, dynamic> m) async {
    final monitor = ref.read(flightMonitorProvider.notifier);
    final book = ref.read(logbookProvider.notifier);
    final logs = ref.read(logbookProvider).value ?? const <FlightLog>[];
    final remote = {
      for (final i in (m['items'] as List).cast<Map>())
        i['id'] as String: i['updatedAt'] as String,
    };
    final plan = planLogbookSync(
      local: {for (final l in logs) l.id: l.updatedAt.toIso8601String()},
      remote: remote,
      pendingDeletes: _pendingDeletes,
    );
    for (var i = 0; i < plan.toFetch.length; i += 50) {
      monitor.sendJson({
        'type': 'logbook_get',
        'ids': plan.toFetch.skip(i).take(50).toList(),
      });
    }
    for (final id in plan.toPush) {
      final log = logs.firstWhere((l) => l.id == id);
      monitor.sendJson({'type': 'logbook_put', 'log': log.toJson()});
    }
    for (final id in plan.toDeleteRemote) {
      monitor.sendJson({'type': 'logbook_delete', 'id': id});
    }
    for (final id in plan.toDeleteLocal) {
      _selfRemoved.add(id);
      await book.delete(id);
    }
    // Desktop no longer has it: nothing left to delete there.
    _pendingDeletes.removeWhere((id) => !remote.containsKey(id));
    _lastSync = DateTime.now();
    state = LogbookSyncState(connected: true, lastSync: _lastSync);
  }

  Future<void> _onEntry(Map<String, dynamic> m) async {
    final log = FlightLog.fromJson(
      Map<String, dynamic>.from(jsonDecode(jsonEncode(m['log'])) as Map),
    );
    final mine = (ref.read(logbookProvider).value ?? const <FlightLog>[])
        .where((l) => l.id == log.id)
        .firstOrNull;
    if (mine != null && !log.updatedAt.isAfter(mine.updatedAt)) return;
    await ref.read(logbookProvider.notifier).upsert(log);
  }
}

final logbookSyncProvider =
    NotifierProvider<LogbookSyncNotifier, LogbookSyncState>(
      LogbookSyncNotifier.new,
    );
