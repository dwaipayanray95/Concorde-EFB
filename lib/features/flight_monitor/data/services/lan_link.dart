import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/sim_bridge_launcher.dart';

/// Flight Monitor over Wi-Fi.
///
/// SimConnect only works on the PC running MSFS, so phones/tablets get live
/// data from the desktop app's bridge over the local network:
///  - the desktop app enables "share to tablet/phone" ([lanShareProvider]);
///    the bridge then listens on the LAN and requires a 6-digit pairing code
///    and broadcasts a UDP beacon on [beaconPort];
///  - the mobile app finds the PC via the beacon ([discoveredBridgesProvider])
///    or a typed IP, and connects with the code ([remoteBridgeProvider]).
const int bridgePort = 8082;
const int beaconPort = 8083;

bool get isMobilePlatform =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

bool get isWindowsDesktop =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

// ---------------------------------------------------------------------------
// Desktop side: share the bridge on the local network.
// ---------------------------------------------------------------------------

class LanShareSettings {
  final bool enabled;
  final String code;
  const LanShareSettings({required this.enabled, required this.code});
}

const _kLanEnabled = 'lan_share_enabled';
const _kLanCode = 'lan_share_code';

String _newPairingCode() =>
    (Random.secure().nextInt(900000) + 100000).toString();

/// Loads the saved LAN settings into [SimBridgeLauncher] -- call before
/// [SimBridgeLauncher.start] so the first bridge launch already has them.
Future<LanShareSettings> loadLanShareIntoLauncher() async {
  final prefs = await SharedPreferences.getInstance();
  var code = prefs.getString(_kLanCode) ?? '';
  if (code.length != 6) {
    code = _newPairingCode();
    await prefs.setString(_kLanCode, code);
  }
  final settings = LanShareSettings(
    enabled: prefs.getBool(_kLanEnabled) ?? false,
    code: code,
  );
  SimBridgeLauncher.lanEnabled = settings.enabled;
  SimBridgeLauncher.pairingCode = settings.code;
  return settings;
}

class LanShareNotifier extends Notifier<LanShareSettings> {
  @override
  LanShareSettings build() => LanShareSettings(
    enabled: SimBridgeLauncher.lanEnabled,
    code: SimBridgeLauncher.pairingCode,
  );

  Future<void> setEnabled(bool enabled) async {
    state = LanShareSettings(enabled: enabled, code: state.code);
    await _save();
  }

  /// New pairing code (un-pairs every phone/tablet).
  Future<void> regenerateCode() async {
    state = LanShareSettings(enabled: state.enabled, code: _newPairingCode());
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kLanEnabled, state.enabled);
    await prefs.setString(_kLanCode, state.code);
    await SimBridgeLauncher.configureLan(
      enabled: state.enabled,
      code: state.code,
    );
  }
}

final lanShareProvider = NotifierProvider<LanShareNotifier, LanShareSettings>(
  LanShareNotifier.new,
);

/// This PC's IPv4 addresses on the local network (to show the user).
final localIpv4Provider = FutureProvider<List<String>>((ref) async {
  try {
    final ifaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [
      for (final i in ifaces)
        for (final a in i.addresses)
          if (_isPrivateLan(a.address)) a.address,
    ];
  } catch (_) {
    return const [];
  }
});

bool _isPrivateLan(String ip) =>
    ip.startsWith('192.168.') ||
    ip.startsWith('10.') ||
    RegExp(r'^172\.(1[6-9]|2\d|3[01])\.').hasMatch(ip);

// ---------------------------------------------------------------------------
// Mobile side: which PC to connect to.
// ---------------------------------------------------------------------------

class RemoteBridge {
  final String host;
  final String code;
  const RemoteBridge({this.host = '', this.code = ''});
  bool get isConfigured => host.isNotEmpty && code.length == 6;

  String get url =>
      'ws://$host:$bridgePort/?code=${Uri.encodeQueryComponent(code)}';
}

const _kRemoteHost = 'remote_bridge_host';
const _kRemoteCode = 'remote_bridge_code';

class RemoteBridgeNotifier extends Notifier<RemoteBridge> {
  @override
  RemoteBridge build() {
    _load();
    return const RemoteBridge();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = RemoteBridge(
      host: prefs.getString(_kRemoteHost) ?? '',
      code: prefs.getString(_kRemoteCode) ?? '',
    );
    if (!state.isConfigured && saved.isConfigured) state = saved;
  }

  Future<void> connect(String host, String code) async {
    state = RemoteBridge(host: host.trim(), code: code.trim());
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kRemoteHost, state.host);
    await prefs.setString(_kRemoteCode, state.code);
  }

  Future<void> forget() async {
    state = const RemoteBridge();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRemoteHost);
    await prefs.remove(_kRemoteCode);
  }
}

final remoteBridgeProvider =
    NotifierProvider<RemoteBridgeNotifier, RemoteBridge>(
      RemoteBridgeNotifier.new,
    );

class DiscoveredBridge {
  final String ip;
  final String name;
  final DateTime lastSeen;
  const DiscoveredBridge(this.ip, this.name, this.lastSeen);
}

/// Parses a bridge beacon datagram; null if it isn't one.
String? parseBeaconName(List<int> data) {
  try {
    final m = jsonDecode(utf8.decode(data));
    if (m is Map && m['app'] == 'concorde-efb-bridge') {
      return (m['host'] ?? 'Sim PC').toString();
    }
  } catch (_) {}
  return null;
}

/// PCs announcing a shared bridge on this network (seen in the last 6 s).
final discoveredBridgesProvider = StreamProvider<List<DiscoveredBridge>>((ref) {
  final controller = StreamController<List<DiscoveredBridge>>();
  final found = <String, DiscoveredBridge>{};
  RawDatagramSocket? socket;
  Timer? prune;

  void emit() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 6));
    found.removeWhere((_, b) => b.lastSeen.isBefore(cutoff));
    controller.add(found.values.toList()..sort((a, b) => a.ip.compareTo(b.ip)));
  }

  RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        beaconPort,
        reuseAddress: true,
      )
      .then((s) {
        socket = s;
        s.broadcastEnabled = true;
        s.listen((event) {
          if (event != RawSocketEvent.read) return;
          final dg = s.receive();
          if (dg == null) return;
          final name = parseBeaconName(dg.data);
          if (name == null) return;
          found[dg.address.address] = DiscoveredBridge(
            dg.address.address,
            name,
            DateTime.now(),
          );
          emit();
        });
      })
      .catchError((_) => controller.add(const <DiscoveredBridge>[]));
  prune = Timer.periodic(const Duration(seconds: 2), (_) => emit());
  emit();

  ref.onDispose(() {
    prune?.cancel();
    socket?.close();
    controller.close();
  });
  return controller.stream;
});
