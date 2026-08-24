import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/models/flight_log_entry.dart';
import '../../data/services/websocket_client.dart';
import '../../data/services/flight_log_service.dart';
import '../../data/services/flight_log_tracker.dart';
import '../../../../core/concorde_logic.dart';
import '../../../../core/sim_bridge_launcher.dart';
import '../../../../providers/efb_providers.dart';

class FlightMonitorState {
  final TelemetryModel? currentTelemetry;
  final bool isConnected;

  /// True from the moment a takeoff is auto-detected until the matching
  /// landing is detected and the flight is saved -- purely informational
  /// (there's no manual record control any more).
  final bool isLoggingFlight;

  FlightMonitorState({
    this.currentTelemetry,
    this.isConnected = false,
    this.isLoggingFlight = false,
  });

  FlightMonitorState copyWith({
    TelemetryModel? currentTelemetry,
    bool? isConnected,
    bool? isLoggingFlight,
  }) {
    return FlightMonitorState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      isConnected: isConnected ?? this.isConnected,
      isLoggingFlight: isLoggingFlight ?? this.isLoggingFlight,
    );
  }
}

class FlightMonitorNotifier extends Notifier<FlightMonitorState> {
  /// The bridge streams at ~25 Hz; repainting the whole LCD panel that often
  /// is wasted work. 10 Hz is visually indistinguishable on a dashboard.
  static const Duration _uiUpdateInterval = Duration(milliseconds: 100);

  /// If the bridge process we spawned is alive but has delivered zero real
  /// telemetry for this long, restart it -- see SimBridgeLauncher.restart
  /// for why a stuck first-connect-before-MSFS-is-up state doesn't recover
  /// on its own within the same process.
  static const _watchdogTimeout = Duration(seconds: 90);
  static const _maxAutoRestarts = 3;

  late WebSocketClient _wsClient;
  late FlightLogTracker _tracker;
  final FlightLogService _logService = FlightLogService();
  StreamSubscription<TelemetryModel>? _wsSubscription;
  Timer? _pingTimer;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int _disconnectedSeconds = 0;
  int _autoRestartCount = 0;

  @override
  FlightMonitorState build() {
    _wsClient = WebSocketClient('ws://localhost:8082');
    _tracker = FlightLogTracker(nearestAirportIcao: _nearestAirportIcao);

    // Connect websocket stream in background
    _wsSubscription = _wsClient.connect().listen(
      _handleLiveTelemetry,
      onError: (_) => _handleDisconnect(),
      onDone: () => _handleDisconnect(),
    );

    // Setup periodic connection state checks
    _pingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.isConnected != _wsClient.isConnected) {
        state = state.copyWith(isConnected: _wsClient.isConnected);
      }

      if (_wsClient.isConnected) {
        _disconnectedSeconds = 0;
        return;
      }
      // Only watch a bridge process WE spawned -- never touch an
      // externally/manually run dev bridge (SimBridgeStatus.alreadyRunning).
      if (SimBridgeLauncher.status.value != SimBridgeStatus.started) return;
      if (_autoRestartCount >= _maxAutoRestarts) return;

      _disconnectedSeconds++;
      if (_disconnectedSeconds >= _watchdogTimeout.inSeconds) {
        _disconnectedSeconds = 0;
        _autoRestartCount++;
        SimBridgeLauncher.restart();
      }
    });

    ref.onDispose(() {
      _pingTimer?.cancel();
      _wsSubscription?.cancel();
      _wsClient.disconnect();
    });

    return FlightMonitorState();
  }

  /// Beyond this, "nearest airport" stops meaning anything useful (e.g. an
  /// add-on-only strip with no real-world counterpart in the offline DB,
  /// or a remote area) -- better to show nothing than a confidently wrong
  /// airport hundreds of miles away.
  static const double _maxSaneAirportDistanceNm = 100;

  String _nearestAirportIcao(double lat, double lon) {
    final airports = ref.read(airportDbProvider).value?.airports;
    if (airports == null || airports.isEmpty) return '';
    String best = '';
    double bestNm = double.infinity;
    for (final a in airports.values) {
      final d = ConcordeLogic.greatCircleNM(lat, lon, a.lat, a.lon);
      if (d < bestNm) {
        bestNm = d;
        best = a.icao;
      }
    }
    return bestNm <= _maxSaneAirportDistanceNm ? best : '';
  }

  void _handleLiveTelemetry(TelemetryModel telemetry) {
    // The tracker sees every frame (not just UI-throttled updates) so
    // distance/reheat-time integration and the takeoff/landing edges are
    // never missed or double-counted.
    final entry = _tracker.ingest(telemetry, DateTime.now());
    if (entry != null) {
      unawaited(_saveEntry(entry));
    }

    final now = DateTime.now();
    if (now.difference(_lastUiUpdate) < _uiUpdateInterval) return;
    _lastUiUpdate = now;

    state = state.copyWith(
      currentTelemetry: telemetry,
      isConnected: true,
      isLoggingFlight: _tracker.isAirborne,
    );
  }

  Future<void> _saveEntry(FlightLogEntry entry) async {
    await _logService.saveEntry(entry);
    ref.invalidate(flightLogHistoryFutureProvider);
  }

  void _handleDisconnect() {
    if (state.isConnected) {
      state = state.copyWith(isConnected: false);
    }
  }

  Future<void> deleteFlightLogEntry(String id) async {
    await _logService.deleteEntry(id);
    ref.invalidate(flightLogHistoryFutureProvider);
  }
}

// Global Providers
final flightMonitorProvider =
    NotifierProvider<FlightMonitorNotifier, FlightMonitorState>(
      FlightMonitorNotifier.new,
    );

final flightLogHistoryFutureProvider = FutureProvider<List<FlightLogEntry>>((
  ref,
) async {
  final service = FlightLogService();
  return service.loadHistory();
});
