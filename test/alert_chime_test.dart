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
}
