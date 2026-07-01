import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/telemetry_model.dart';
import '../../data/services/websocket_client.dart';
import '../../data/services/flight_recorder_service.dart';

class FlightMonitorState {
  final TelemetryModel? currentTelemetry;
  final bool isRecording;
  final int recordedFramesCount;
  final bool isConnected;
  
  // Playback/History timeline parameters
  final bool isPlaybackMode;
  final List<TelemetryModel> playbackFrames;
  final int playbackIndex;
  
  FlightMonitorState({
    this.currentTelemetry,
    this.isRecording = false,
    this.recordedFramesCount = 0,
    this.isConnected = false,
    this.isPlaybackMode = false,
    this.playbackFrames = const [],
    this.playbackIndex = 0,
  });

  FlightMonitorState copyWith({
    TelemetryModel? currentTelemetry,
    bool? isRecording,
    int? recordedFramesCount,
    bool? isConnected,
    bool? isPlaybackMode,
    List<TelemetryModel>? playbackFrames,
    int? playbackIndex,
  }) {
    return FlightMonitorState(
      currentTelemetry: currentTelemetry ?? this.currentTelemetry,
      isRecording: isRecording ?? this.isRecording,
      recordedFramesCount: recordedFramesCount ?? this.recordedFramesCount,
      isConnected: isConnected ?? this.isConnected,
      isPlaybackMode: isPlaybackMode ?? this.isPlaybackMode,
      playbackFrames: playbackFrames ?? this.playbackFrames,
      playbackIndex: playbackIndex ?? this.playbackIndex,
    );
  }
}

class FlightMonitorNotifier extends Notifier<FlightMonitorState> {
  late WebSocketClient _wsClient;
  final FlightRecorderService _recorderService = FlightRecorderService();
  StreamSubscription<TelemetryModel>? _wsSubscription;
  Timer? _pingTimer;

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
    });

    ref.onDispose(() {
      _pingTimer?.cancel();
      _wsSubscription?.cancel();
      _wsClient.disconnect();
    });

    return FlightMonitorState();
  }

  void _handleLiveTelemetry(TelemetryModel telemetry) {
    if (state.isPlaybackMode) return; // Do not overwrite state during log playback

    if (state.isRecording) {
      _recorderService.addFrame(telemetry);
    }

    state = state.copyWith(
      currentTelemetry: telemetry,
      isConnected: true,
      recordedFramesCount: state.isRecording ? _recorderService.currentFrameCount : 0,
    );
  }

  void _handleDisconnect() {
    if (state.isConnected) {
      state = state.copyWith(isConnected: false);
    }
  }

  void startRecording() {
    if (state.isPlaybackMode) return;
    _recorderService.startRecording();
    state = state.copyWith(
      isRecording: true,
      recordedFramesCount: 0,
    );
  }

  Future<FlightRecordHeader?> stopRecording() async {
    if (!state.isRecording) return null;
    final header = await _recorderService.stopAndSaveRecording();
    state = state.copyWith(
      isRecording: false,
      recordedFramesCount: 0,
    );
    // Refresh history list implicitly by forcing updates where needed
    ref.invalidate(flightHistoryFutureProvider);
    return header;
  }

  Future<void> startPlayback(String flightId) async {
    final frames = await _recorderService.loadFlightFrames(flightId);
    if (frames.isEmpty) return;

    state = state.copyWith(
      isPlaybackMode: true,
      playbackFrames: frames,
      playbackIndex: 0,
      currentTelemetry: frames.first,
    );
  }

  void setPlaybackIndex(int index) {
    if (!state.isPlaybackMode || index < 0 || index >= state.playbackFrames.length) return;
    state = state.copyWith(
      playbackIndex: index,
      currentTelemetry: state.playbackFrames[index],
    );
  }

  void exitPlayback() {
    state = state.copyWith(
      isPlaybackMode: false,
      playbackFrames: [],
      playbackIndex: 0,
      currentTelemetry: null,
    );
  }

  Future<void> deleteRecordedFlight(String flightId) async {
    await _recorderService.deleteFlight(flightId);
    ref.invalidate(flightHistoryFutureProvider);
  }
}

// Global Providers
final flightMonitorProvider = NotifierProvider<FlightMonitorNotifier, FlightMonitorState>(
  FlightMonitorNotifier.new,
);

final flightHistoryFutureProvider = FutureProvider<List<FlightRecordHeader>>((ref) async {
  final service = FlightRecorderService();
  return service.loadFlightHistory();
});
