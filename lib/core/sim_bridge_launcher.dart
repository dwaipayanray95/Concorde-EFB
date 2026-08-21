import 'dart:io';
import 'package:flutter/foundation.dart';

/// Outcome of the last [SimBridgeLauncher.start] attempt. Distinguishes
/// "the bridge process itself never launched" (exe missing/blocked, most
/// commonly an antivirus/SmartScreen quarantine of the unsigned PyInstaller
/// exe) from "the bridge is running fine, MSFS/SimConnect just isn't
/// connected yet" -- these look identical as a bare "Disconnected" in the
/// UI otherwise, and are diagnosed completely differently.
enum SimBridgeStatus {
  unsupportedPlatform,
  alreadyRunning,
  started,
  exeNotFound,
  launchFailed,
}

/// Launches and manages the bundled SimConnect telemetry bridge
/// (windows/simbridge/msfs_bridge/msfs_bridge.exe) so Flight Monitor works
/// out of the box without users installing Python or running anything
/// manually. The bridge is a standalone PyInstaller build of
/// tools/simbridge/msfs_bridge.py.
class SimBridgeLauncher {
  SimBridgeLauncher._();

  static Process? _process;

  /// Result of the most recent [start] call, and the error message (if any)
  /// -- exposed so the UI can tell a genuine launch failure apart from
  /// "bridge is up, just waiting on MSFS" instead of a bare disconnected dot.
  static final ValueNotifier<SimBridgeStatus?> status = ValueNotifier(null);
  static String? lastError;

  static bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  /// Starts the bridge if it isn't already running (either spawned by us in
  /// a prior call, or already listening from an external instance).
  static Future<SimBridgeStatus> start() async {
    if (!_isSupportedPlatform) {
      return status.value = SimBridgeStatus.unsupportedPlatform;
    }
    if (_process != null) {
      return status.value = SimBridgeStatus.started;
    }

    if (await _isPortOpen('127.0.0.1', 8082)) {
      // Another instance (or a dev bridge) is already serving telemetry.
      return status.value = SimBridgeStatus.alreadyRunning;
    }

    final exePath = _resolveBridgeExePath();
    if (exePath == null || !File(exePath).existsSync()) {
      debugPrint('SimBridgeLauncher: bridge exe not found, skipping launch.');
      lastError =
          'Bridge exe not found at expected path (${exePath ?? "unresolved"}).';
      return status.value = SimBridgeStatus.exeNotFound;
    }

    try {
      _process = await Process.start(
        exePath,
        [],
        workingDirectory: File(exePath).parent.path,
        mode: ProcessStartMode.normal,
      );
      return status.value = SimBridgeStatus.started;
    } catch (e) {
      debugPrint('SimBridgeLauncher: failed to start bridge: $e');
      _process = null;
      lastError = e.toString();
      return status.value = SimBridgeStatus.launchFailed;
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
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(milliseconds: 400),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }
}
