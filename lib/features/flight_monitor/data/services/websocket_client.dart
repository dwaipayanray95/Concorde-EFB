import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/telemetry_model.dart';

class WebSocketClient {
  final String url;
  WebSocketChannel? _channel;
  StreamController<TelemetryModel>? _controller;
  Timer? _reconnectTimer;
  bool _isClosed = false;
  bool _isConnected = false;

  WebSocketClient(this.url);

  bool get isConnected => _isConnected;

  Stream<TelemetryModel> connect() {
    _isClosed = false;
    _controller = StreamController<TelemetryModel>.broadcast(
      onListen: _startConnection,
      onCancel: disconnect,
    );
    return _controller!.stream;
  }

  void _startConnection() {
    if (_isClosed) return;
    _reconnectTimer?.cancel();
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        (data) {
          _isConnected = true;
          try {
            final Map<String, dynamic> decoded = jsonDecode(data);
            final model = TelemetryModel.fromJson(decoded);
            _controller?.add(model);
          } catch (_) {
            // Silently absorb JSON decode errors
          }
        },
        onError: (err) {
          _isConnected = false;
          _scheduleReconnect();
        },
        onDone: () {
          _isConnected = false;
          _scheduleReconnect();
        },
        cancelOnError: true,
      );
    } catch (_) {
      _isConnected = false;
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_isClosed) return;
    _channel?.sink.close();
    _reconnectTimer?.cancel();
    
    // Attempt reconnect every 2 seconds
    _reconnectTimer = Timer(const Duration(seconds: 2), () {
      _startConnection();
    });
  }

  void disconnect() {
    _isClosed = true;
    _isConnected = false;
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _controller?.close();
  }
}
