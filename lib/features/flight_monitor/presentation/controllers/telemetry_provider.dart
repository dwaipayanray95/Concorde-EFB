import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/services/websocket_client.dart';
import '../../../../core/sim_bridge_launcher.dart';

class FlightMonitorState {
  final TelemetryModel? currentTelemetry;
  final bool isConnected;

  FlightMonitorState({this.currentTelemetry, this.isConnected = false});

  FlightMonitorState copyWith({
    TelemetryModel? currentTelemetry,
    bool? isConnected,
  }) {
    return FlightMonitorState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      isConnected: isConnected ?? this.isConnected,
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
  StreamSubscription<TelemetryModel>? _wsSubscription;
  Timer? _pingTimer;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int _disconnectedSeconds = 0;
  int _autoRestartCount = 0;

  @override
  FlightMonitorState build() {
    _wsClient = WebSocketClient('ws://localhost:8082');

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

  void _handleLiveTelemetry(TelemetryModel telemetry) {
    final now = DateTime.now();
    if (now.difference(_lastUiUpdate) < _uiUpdateInterval) return;
    _lastUiUpdate = now;

    state = state.copyWith(currentTelemetry: telemetry, isConnected: true);
  }

  void _handleDisconnect() {
    if (state.isConnected) {
      state = state.copyWith(isConnected: false);
    }
  }
}

// Global Providers
final flightMonitorProvider =
    NotifierProvider<FlightMonitorNotifier, FlightMonitorState>(
      FlightMonitorNotifier.new,
    );
