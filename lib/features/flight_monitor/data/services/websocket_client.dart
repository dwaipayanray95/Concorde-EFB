import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/telemetry_model.dart';

/// Bridge-reported SimConnect state, from `{"type": "status", ...}` frames
/// (see tools/simbridge/msfs_bridge.py). Separate from the socket itself so
/// the UI can tell "bridge down" from "bridge up, MSFS not connected" from
/// "MSFS connected but sitting in the menu / paused".
class BridgeStatus {
  final bool socketConnected;
  final bool simConnected;
  final bool receivingData;
  final String message;

  const BridgeStatus({
    this.socketConnected = false,
    this.simConnected = false,
    this.receivingData = false,
    this.message = '',
  });

  static const offline = BridgeStatus();
}

class WebSocketClient {
  /// The bridge sends a status frame at least every 2s; if nothing at all
  /// arrives for this long the socket is considered dead (hung bridge or a
  /// half-open TCP connection) and is torn down and reopened.
  static const _silenceTimeout = Duration(seconds: 6);

  final String url;
  WebSocketChannel? _channel;
  StreamSubscription? _channelSub;
  StreamController<TelemetryModel>? _controller;
  final _statusController = StreamController<BridgeStatus>.broadcast();
  Timer? _reconnectTimer;
  Timer? _silenceTimer;
  bool _isClosed = false;
  BridgeStatus _status = BridgeStatus.offline;

  WebSocketClient(this.url);

  BridgeStatus get status => _status;
  bool get isConnected => _status.socketConnected;
  Stream<BridgeStatus> get statusStream => _statusController.stream;

  Stream<TelemetryModel> connect() {
    _isClosed = false;
    _controller = StreamController<TelemetryModel>.broadcast(
      onListen: _startConnection,
      onCancel: disconnect,
    );
    return _controller!.stream;
  }

  void _setStatus(BridgeStatus s) {
    _status = s;
    if (!_statusController.isClosed) _statusController.add(s);
  }

  void _armSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(_silenceTimeout, _scheduleReconnect);
  }

  void _startConnection() {
    if (_isClosed) return;
    _reconnectTimer?.cancel();

    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _armSilenceTimer();
      _channelSub = _channel!.stream.listen(
        (data) {
          _armSilenceTimer();
          try {
            final Map<String, dynamic> decoded = jsonDecode(data);
            if (decoded['type'] == 'status') {
              _setStatus(BridgeStatus(
                socketConnected: true,
                simConnected: decoded['simConnected'] == true,
                receivingData: decoded['receivingData'] == true,
                message: (decoded['message'] ?? '').toString(),
              ));
              return;
            }
            // Telemetry (also accepts legacy untyped frames from older bridges).
            if (!_status.receivingData) {
              _setStatus(BridgeStatus(
                socketConnected: true,
                simConnected: true,
                receivingData: true,
                message: _status.message,
              ));
            }
            _controller?.add(TelemetryModel.fromJson(decoded));
          } catch (_) {
            // Ignore malformed frames.
          }
        },
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: true,
      );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isClosed) return;
    _silenceTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _channel = null;
    _setStatus(BridgeStatus.offline);
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), _startConnection);
  }

  void disconnect() {
    _isClosed = true;
    _reconnectTimer?.cancel();
    _silenceTimer?.cancel();
    _channelSub?.cancel();
    _channel?.sink.close();
    _setStatus(BridgeStatus.offline);
    _controller?.close();
    _statusController.close();
  }
}
