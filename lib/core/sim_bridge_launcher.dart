import 'dart:async';
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

/// Launches and supervises the bundled SimConnect telemetry bridge
/// (simbridge/msfs_bridge/msfs_bridge.exe next to the app exe), a standalone
/// PyInstaller build of tools/simbridge/msfs_bridge.py.
///
/// The bridge handles SimConnect connect/disconnect/reconnect itself (MSFS
/// starting late, quitting, crashing), so this class only has to keep the
/// *process* alive: respawn it if it exits, and replace a hung leftover
/// bundled bridge found holding the port at startup.
class SimBridgeLauncher {
  SimBridgeLauncher._();

  static const _port = 8082;
  static const _exeName = 'msfs_bridge.exe';

  static Process? _process;
  static bool _stopping = false;
  static int _crashCount = 0;
  static Timer? _respawnTimer;

  /// LAN sharing for the phone/tablet app: when on, the bridge listens on
  /// the local network (not just this PC) and requires [pairingCode] from
  /// network clients. Set via [configureLan] before/after [start].
  static bool lanEnabled = false;
  static String pairingCode = '';

  /// Applies new LAN settings; respawns the bridge we own so they take
  /// effect (an external/dev bridge is never touched).
  static Future<void> configureLan({
    required bool enabled,
    required String code,
  }) async {
    final changed = enabled != lanEnabled || code != pairingCode;
    lanEnabled = enabled;
    pairingCode = code;
    if (changed && _process != null) await restart();
  }

  /// Result of the most recent [start] call, and the error message (if any).
  static final ValueNotifier<SimBridgeStatus?> status = ValueNotifier(null);
  static String? lastError;

  static bool get _isSupportedPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static Future<SimBridgeStatus> start() async {
    if (!_isSupportedPlatform) {
      return status.value = SimBridgeStatus.unsupportedPlatform;
    }
    if (_process != null) {
      return status.value = SimBridgeStatus.started;
    }
    _stopping = false;

    if (await _isPortOpen()) {
      if (await _bridgeResponds()) {
        // A healthy bridge (another app instance or a dev bridge) is serving.
        return status.value = SimBridgeStatus.alreadyRunning;
      }
      // Something holds the port but never answers -- typically a hung
      // bundled bridge left over from an earlier session. Only ever kill our
      // own shipped exe by image name, never a python.exe dev bridge.
      debugPrint('SimBridgeLauncher: port $_port held by unresponsive process, clearing.');
      await Process.run('taskkill', ['/F', '/IM', _exeName]);
      await Future.delayed(const Duration(milliseconds: 700));
      if (await _isPortOpen()) {
        lastError = 'Port $_port is held by another program.';
        return status.value = SimBridgeStatus.alreadyRunning;
      }
    }

    final exePath = _resolveBridgeExePath();
    if (!File(exePath).existsSync()) {
      debugPrint('SimBridgeLauncher: bridge exe not found, skipping launch.');
      lastError = 'Bridge exe not found at expected path ($exePath).';
      return status.value = SimBridgeStatus.exeNotFound;
    }

    try {
      final process = await Process.start(
        exePath,
        [],
        workingDirectory: File(exePath).parent.path,
        mode: ProcessStartMode.normal,
        environment: {
          'SIMBRIDGE_LAN': lanEnabled ? '1' : '0',
          'SIMBRIDGE_CODE': pairingCode,
        },
      );
      _process = process;
      // Drain pipes so the child can never block on a full stdout/stderr.
      process.stdout.drain<void>();
      process.stderr.drain<void>();
      final startedAt = DateTime.now();
      process.exitCode.then((code) => _onExit(process, code, startedAt));
      return status.value = SimBridgeStatus.started;
    } catch (e) {
      debugPrint('SimBridgeLauncher: failed to start bridge: $e');
      _process = null;
      lastError = e.toString();
      return status.value = SimBridgeStatus.launchFailed;
    }
  }

  static void _onExit(Process process, int code, DateTime startedAt) {
    if (!identical(process, _process)) return; // already replaced/stopped
    _process = null;
    if (_stopping) return;
    debugPrint('SimBridgeLauncher: bridge exited with code $code, respawning.');
    // Reset the backoff after a long healthy run; otherwise back off up to 30s.
    if (DateTime.now().difference(startedAt) > const Duration(minutes: 2)) {
      _crashCount = 0;
    }
    _crashCount++;
    lastError = 'Bridge exited unexpectedly (code $code).';
    final delay = Duration(seconds: (_crashCount * 2).clamp(1, 30));
    _respawnTimer?.cancel();
    _respawnTimer = Timer(delay, start);
  }

  /// Terminates the bridge process we spawned, if any. Safe to call
  /// multiple times and safe to call even if we never started it.
  static void stop() {
    _stopping = true;
    _respawnTimer?.cancel();
    _process?.kill();
    _process = null;
  }

  /// Kills and respawns the bridge we spawned (used by the hung-socket
  /// watchdog in telemetry_provider.dart). Never touches an external bridge.
  static Future<SimBridgeStatus> restart() async {
    final hadOwnProcess = _process != null;
    stop();
    if (hadOwnProcess) {
      // Give Windows a moment to release the port before respawning.
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return start();
  }

  /// Kept for API compatibility with main.dart/home_screen.dart. The bridge
  /// now reconnects to MSFS on its own, so there is nothing to watch for.
  static void startWatching() {}
  static void stopWatching() {}

  static String _resolveBridgeExePath() {
    final appDir = File(Platform.resolvedExecutable).parent.path;
    return '$appDir\\simbridge\\msfs_bridge\\$_exeName';
  }

  static Future<bool> _isPortOpen() async {
    try {
      final socket = await Socket.connect(
        '127.0.0.1',
        _port,
        timeout: const Duration(milliseconds: 400),
      );
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// True if whatever is on the port completes a WebSocket handshake.
  static Future<bool> _bridgeResponds() async {
    try {
      final ws = await WebSocket.connect('ws://127.0.0.1:$_port')
          .timeout(const Duration(seconds: 3));
      await ws.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}
