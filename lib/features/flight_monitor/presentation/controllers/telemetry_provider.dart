import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/services/websocket_client.dart';
import '../../../../core/sim_bridge_launcher.dart';

/// The last landing, latched in the app -- the bridge only flags a
/// touchdown for ~5 s, which is far too short to read it.
class TouchdownRecord {
  final double vsFpm;
  final double pitchDeg;
  final double gForce;
  final String zulu;
  const TouchdownRecord({
    required this.vsFpm,
    required this.pitchDeg,
    required this.gForce,
    required this.zulu,
  });
}

class FlightMonitorState {
  final TelemetryModel? currentTelemetry;

  /// Total fuel flow (kg/h) smoothed over ~30 s -- the raw sim value jumps
  /// with every throttle/reheat change, which makes endurance/landing-fuel
  /// predictions flicker. Null until the first frame.
  final double? smoothedFuelFlowKgH;

  final TouchdownRecord? lastTouchdown;

  /// True only while live telemetry is actually flowing from MSFS.
  final bool isConnected;

  /// Full bridge/SimConnect state for diagnostics in the UI.
  final BridgeStatus bridge;

  FlightMonitorState({
    this.currentTelemetry,
    this.smoothedFuelFlowKgH,
    this.lastTouchdown,
    this.isConnected = false,
    this.bridge = BridgeStatus.offline,
  });

  FlightMonitorState copyWith({
    TelemetryModel? currentTelemetry,
    double? smoothedFuelFlowKgH,
    TouchdownRecord? lastTouchdown,
    bool? isConnected,
    BridgeStatus? bridge,
  }) {
    return FlightMonitorState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      smoothedFuelFlowKgH: smoothedFuelFlowKgH ?? this.smoothedFuelFlowKgH,
      lastTouchdown: lastTouchdown ?? this.lastTouchdown,
      isConnected: isConnected ?? this.isConnected,
      bridge: bridge ?? this.bridge,
    );
  }
}

class FlightMonitorNotifier extends Notifier<FlightMonitorState> {
  /// The bridge streams at ~25 Hz; repainting the whole LCD panel that often
  /// is wasted work. 10 Hz is visually indistinguishable on a dashboard.
  static const Duration _uiUpdateInterval = Duration(milliseconds: 100);

  /// If a bridge process we spawned is running but its WebSocket hasn't been
  /// reachable for this long, it is hung -- respawn it. (SimConnect itself
  /// reconnects inside the bridge, so this only covers the process/socket.)
  static const _watchdogTimeout = Duration(seconds: 20);

  late WebSocketClient _wsClient;
  StreamSubscription<TelemetryModel>? _wsSubscription;
  StreamSubscription<BridgeStatus>? _statusSubscription;
  Timer? _watchdogTimer;
  DateTime _lastUiUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  int _unreachableSeconds = 0;

  @override
  FlightMonitorState build() {
    _wsClient = WebSocketClient('ws://127.0.0.1:8082');

    _wsSubscription = _wsClient.connect().listen(_handleLiveTelemetry);
    _statusSubscription = _wsClient.statusStream.listen(_handleStatus);

    _watchdogTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_wsClient.isConnected) {
        _unreachableSeconds = 0;
        return;
      }
      // Only ever restart a bridge process WE spawned -- never an
      // externally/manually run dev bridge (SimBridgeStatus.alreadyRunning).
      if (SimBridgeLauncher.status.value != SimBridgeStatus.started) return;
      if (++_unreachableSeconds >= _watchdogTimeout.inSeconds) {
        _unreachableSeconds = 0;
        SimBridgeLauncher.restart();
      }
    });

    ref.onDispose(() {
      _watchdogTimer?.cancel();
      _wsSubscription?.cancel();
      _statusSubscription?.cancel();
      _wsClient.disconnect();
    });

    return FlightMonitorState();
  }

  void _handleStatus(BridgeStatus s) {
    final live = s.socketConnected && s.receivingData;
    state = FlightMonitorState(
      // Drop stale frames once data stops so the UI doesn't show frozen values.
      currentTelemetry: live ? state.currentTelemetry : null,
      smoothedFuelFlowKgH: live ? state.smoothedFuelFlowKgH : null,
      lastTouchdown: state.lastTouchdown,
      isConnected: live,
      bridge: s,
    );
  }

  /// Time constant of the fuel-flow smoothing.
  static const _flowSmoothingS = 30.0;

  void _handleLiveTelemetry(TelemetryModel telemetry) {
    final now = DateTime.now();
    final touchdown =
        telemetry.isLanding &&
            (state.lastTouchdown == null ||
                state.currentTelemetry?.isLanding != true)
        ? TouchdownRecord(
            vsFpm: telemetry.touchdownVS,
            pitchDeg: telemetry.touchdownPitch,
            gForce: telemetry.touchdownGForce,
            zulu: telemetry.zuluTime,
          )
        : null;
    if (touchdown == null &&
        now.difference(_lastUiUpdate) < _uiUpdateInterval) {
      return;
    }
    final dtS = now.difference(_lastUiUpdate).inMilliseconds / 1000.0;
    _lastUiUpdate = now;

    final raw = telemetry.fuelBurnTotal;
    final prev = state.smoothedFuelFlowKgH;
    final alpha = (dtS / _flowSmoothingS).clamp(0.0, 1.0);
    final smoothed = prev == null ? raw : prev + (raw - prev) * alpha;

    state = state.copyWith(
      currentTelemetry: telemetry,
      smoothedFuelFlowKgH: smoothed,
      lastTouchdown: touchdown,
      isConnected: true,
    );
  }
}

// Global Providers
final flightMonitorProvider =
    NotifierProvider<FlightMonitorNotifier, FlightMonitorState>(
      FlightMonitorNotifier.new,
    );
