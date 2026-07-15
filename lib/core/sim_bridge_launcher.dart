import 'dart:io';
import 'package:flutter/foundation.dart';

/// Launches and manages the bundled SimConnect telemetry bridge
/// (windows/simbridge/msfs_bridge/msfs_bridge.exe) so Flight Monitor works
/// out of the box without users installing Python or running anything
/// manually. The bridge is a standalone PyInstaller build of
/// tools/simbridge/msfs_bridge.py.
class SimBridgeLauncher {
  SimBridgeLauncher._();

  static Process? _process;

  static bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Starts the bridge if it isn't already running (either spawned by us in
  /// a prior call, or already listening from an external instance).
  static Future<void> start() async {
    if (!_isSupportedPlatform || _process != null) return;

    if (await _isPortOpen('127.0.0.1', 8082)) {
      // Another instance (or a dev bridge) is already serving telemetry.
      return;
    }

    final exePath = _resolveBridgeExePath();
    if (exePath == null || !File(exePath).existsSync()) {
      debugPrint('SimBridgeLauncher: bridge exe not found, skipping launch.');
      return;
    }

    try {
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: File(exePath).parent.path,
        mode: ProcessStartMode.normal,
      );
    } catch (e) {
      debugPrint('SimBridgeLauncher: failed to start bridge: $e');
      _process = null;
    }
  }

  /// Terminates the bridge process we spawned, if any. Safe to call
  /// multiple times and safe to call even if we never started it.
  static void stop() {
    _process?.kill();
    _process = null;
  }

  static String? _resolveBridgeExePath() {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    return '$appDir\\simbridge\\msfs_bridge\\msfs_bridge.exe';
  }

  static Future<bool> _isPortOpen(String host, int port) async {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(milliseconds: 400));
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
