import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:concorde_efb/features/flight_monitor/data/services/lan_link.dart';

void main() {
  test('beacon parsing', () {
    expect(
      parseBeaconName(
        utf8.encode(
          jsonEncode({
            'app': 'concorde-efb-bridge',
            'v': 1,
            'port': 8082,
            'host': 'SIM-PC',
          }),
        ),
      ),
      'SIM-PC',
    );
    expect(parseBeaconName(utf8.encode('{"app":"other"}')), isNull);
    expect(parseBeaconName(utf8.encode('garbage')), isNull);
  });

  test('remote bridge url carries the pairing code', () {
    const r = RemoteBridge(host: '192.168.1.20', code: '482913');
    expect(r.isConfigured, isTrue);
    expect(r.url, 'ws://192.168.1.20:8082/?code=482913');
    expect(
      const RemoteBridge(host: '192.168.1.20', code: '12').isConfigured,
      isFalse,
    );
  });
}
