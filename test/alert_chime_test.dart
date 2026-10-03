import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:concorde_efb/features/flight_monitor/presentation/controllers/alert_chime.dart';
import 'package:concorde_efb/features/flight_monitor/presentation/controllers/live_alerts_provider.dart';

class _FakeAlerts extends Notifier<List<LiveAlert>> {
  @override
  List<LiveAlert> build() => const [];
  void set(List<LiveAlert> v) => state = v;
}

final _fake = NotifierProvider<_FakeAlerts, List<LiveAlert>>(_FakeAlerts.new);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer make() {
    final c = ProviderContainer(
      overrides: [liveAlertsProvider.overrideWith((ref) => ref.watch(_fake))],
    );
    c.listen(alertChimeProvider, (_, _) {});
    return c;
  }

  // Alerts propagate to the chime listener asynchronously.
  Future<void> set(ProviderContainer c, List<LiveAlert> v) async {
    c.read(_fake.notifier).set(v);
    c.read(liveAlertsProvider);
    await Future<void>.delayed(Duration.zero);
  }

  const caution = LiveAlert('DESCEND NOW', critical: false);
  const warning = LiveAlert('CG AFT LIMIT', critical: true);

  test('one chime per new alert, not repeated while it stays active', () async {
    final c = make();
    addTearDown(c.dispose);
    final chime = c.read(alertChimeProvider.notifier);

    await set(c, [caution]);
    await set(c, [caution]); // still active
    await set(c, [caution]);
    expect(chime.played, [false]);

    await set(c, [caution, warning]); // new warning
    expect(chime.played, [false, true]);
  });

  test('warning wins when several alerts appear together', () async {
    final c = make();
    addTearDown(c.dispose);
    await set(c, [caution, warning]);
    expect(c.read(alertChimeProvider.notifier).played, [true]);
  });

  test('flicker off/on within 10 s does not re-chime', () async {
    final c = make();
    addTearDown(c.dispose);
    final chime = c.read(alertChimeProvider.notifier);
    await set(c, [caution]);
    await set(c, []);
    await set(c, [caution]);
    expect(chime.played, [false]);
  });

  test('muted: no chimes', () async {
    final c = make();
    addTearDown(c.dispose);
    final chime = c.read(alertChimeProvider.notifier);
    await chime.setEnabled(false);
    await set(c, [warning]);
    expect(chime.played, isEmpty);
  });

  test('urgent warnings re-chime every 2 s, DESCEND NOW every 12 s', () async {
    final c = make();
    addTearDown(c.dispose);
    final chime = c.read(alertChimeProvider.notifier);
    const overspeed = LiveAlert(
      'MACH > MMO',
      critical: true,
      repeatEvery: Duration(seconds: 2),
    );
    const descend = LiveAlert(
      'DESCEND NOW',
      critical: false,
      repeatEvery: Duration(seconds: 12),
    );
    await set(c, [overspeed, descend]);
    expect(chime.played, [true]); // first appearance: one (warning) chime

    final t0 = DateTime.now();
    chime.checkRepeatsAt(t0.add(const Duration(seconds: 1)));
    expect(chime.played.length, 1); // not yet
    chime.checkRepeatsAt(t0.add(const Duration(seconds: 2, milliseconds: 100)));
    expect(chime.played, [true, true]); // overspeed repeat
    chime.checkRepeatsAt(
      t0.add(const Duration(seconds: 12, milliseconds: 200)),
    );
    // Both due: a single chime, the most severe.
    expect(chime.played, [true, true, true]);

    // Cleared: no more repeats.
    await set(c, []);
    chime.checkRepeatsAt(t0.add(const Duration(seconds: 30)));
    expect(chime.played.length, 3);
  });

  test('one-shot alerts never repeat', () async {
    final c = make();
    addTearDown(c.dispose);
    final chime = c.read(alertChimeProvider.notifier);
    const fuel = LiveAlert('FUEL BELOW FINAL RESERVE AT DEST', critical: true);
    await set(c, [fuel]);
    chime.checkRepeatsAt(DateTime.now().add(const Duration(minutes: 5)));
    expect(chime.played, [true]);
  });
}
