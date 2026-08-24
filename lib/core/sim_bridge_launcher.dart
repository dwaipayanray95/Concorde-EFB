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

  /// Kills and respawns the bridge as a fresh OS process. The underlying
  /// Python SimConnect wrapper can get stuck if it first attempts to
  /// connect before MSFS is actually running -- retrying `SimConnect()`
  /// within that same long-lived process doesn't reliably recover, even
  /// though the bridge's own retry loop is otherwise correct, which is
  /// exactly why "just restart the app" was the previous workaround. A
  /// brand new process gets fresh OS-level connection state instead. Only
  /// ever kills a process THIS launcher spawned (`_process`) -- a no-op if
  /// the app never started one (e.g. an externally/manually run dev bridge).
  static Future<SimBridgeStatus> restart() async {
    final hadOwnProcess = _process != null;
    stop();
    if (hadOwnProcess) {
      // Give Windows a moment to release the port before respawning.
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return start();
  }

  static Timer? _watchTimer;
  static bool _lastMsfsRunning = false;

  /// Starts polling for MSFS's own process, independent of the bridge's
  /// connection state -- lets us react to "the game just launched" as an
  /// event rather than guessing from elapsed time. This is what makes it
  /// safe to open the app long before starting the sim: nothing restarts
  /// while MSFS isn't running, so there's no wasted retry budget by the
  /// time it actually launches.
  static void startWatching() {
    if (!_isSupportedPlatform || _watchTimer != null) return;
    _watchTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final running = await _isMsfsRunning();
      if (running && !_lastMsfsRunning) {
        // Rising edge: MSFS's process just appeared. Force a fresh bridge
        // process now so its first SimConnect attempt lands against an
        // actually-running sim -- this is the actual fix for the "opened
        // the app 5 minutes before starting the game" case, since the
        // bridge may have already made several failed attempts while MSFS
        // was closed and gotten into the stuck state `restart()` documents.
        debugPrint(
          'SimBridgeLauncher: MSFS process detected, restarting bridge.',
        );
        await restart();
      }
      _lastMsfsRunning = running;
    });
  }

  static void stopWatching() {
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  /// MSFS 2020 and 2024 both ship as an executable prefixed "FlightSimulator"
  /// (e.g. FlightSimulator.exe / FlightSimulator2024.exe across Steam/MS
  /// Store builds) -- tasklist's IMAGENAME filter supports a trailing
  /// wildcard, so one query covers every variant without needing the exact
  /// per-version/per-storefront binary name.
  static Future<bool> _isMsfsRunning() async {
    if (!_isSupportedPlatform) return false;
    try {
      final result = await Process.run('tasklist', [
        '/FI',
        'IMAGENAME eq FlightSimulator*.exe',
      ]);
      final out = (result.stdout as String?)?.toLowerCase() ?? '';
      return out.contains('flightsimulator');
    } catch (_) {
      return false;
    }
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
