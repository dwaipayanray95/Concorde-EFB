import 'package:concorde_efb/features/flight_monitor/presentation/widgets/flight_monitor/android_beta_prompt.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AndroidBetaPromptPolicy.resetSession();
  });

  test('shows on a fresh install, once per session', () async {
    final prefs = await SharedPreferences.getInstance();
    expect(AndroidBetaPromptPolicy.shouldShow(prefs), isTrue);
    AndroidBetaPromptPolicy.markShown();
    expect(AndroidBetaPromptPolicy.shouldShow(prefs), isFalse);
    AndroidBetaPromptPolicy.resetSession(); // next launch
    expect(AndroidBetaPromptPolicy.shouldShow(prefs), isTrue);
  });

  test('never hides it for good', () async {
    final prefs = await SharedPreferences.getInstance();
    await AndroidBetaPromptPolicy.never(prefs);
    expect(AndroidBetaPromptPolicy.shouldShow(prefs), isFalse);
  });

  test('remind later hides it for 3 days, then it returns', () async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 10, 20, 12);
    await AndroidBetaPromptPolicy.snooze(prefs, now: now);
    expect(
      AndroidBetaPromptPolicy.shouldShow(
        prefs,
        now: now.add(const Duration(days: 2)),
      ),
      isFalse,
    );
    expect(
      AndroidBetaPromptPolicy.shouldShow(
        prefs,
        now: now.add(const Duration(days: 3, minutes: 1)),
      ),
      isTrue,
    );
  });
}
