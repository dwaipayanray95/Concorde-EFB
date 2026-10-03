import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_alerts_provider.dart';

/// Plays a chime when a live alert first appears:
///  - red warning  -> two-tone chime (assets/sounds/warning.wav)
///  - amber caution -> single soft chime (assets/sounds/caution.wav)
/// If several alerts appear at once, only the most severe chime plays.
/// An alert that blinks off and back on within [_rearmAfter] doesn't
/// re-chime (e.g. DESCEND NOW flickering at its threshold).
/// Alerts with [LiveAlert.repeatEvery] re-chime at that interval while they
/// stay active (overspeed / CG / gear warnings every 2 s, DESCEND NOW every
/// 12 s); everything else chimes once.
///
/// State = chimes enabled (persisted). Watched from HomeScreen so it runs
/// whichever tab is open.
class AlertChimeNotifier extends Notifier<bool> {
  static const _prefKey = 'alert_chimes_enabled';
  static const _rearmAfter = Duration(seconds: 10);

  final Map<String, DateTime> _lastSeen = {};
  Set<String> _active = {};
  final Map<String, DateTime> _lastChimed = {};
  List<LiveAlert> _current = const [];
  Timer? _repeatTimer;

  /// Alerts silenced by tapping their pill: no chime until this time. If the
  /// alert is still active afterwards it chimes again; if it clears, the
  /// silence is dropped so a later recurrence chimes normally.
  final Map<String, DateTime> _silencedUntil = {};
  static const silenceFor = Duration(seconds: 10);

  /// Severity of every chime played (true = warning), for tests.
  @visibleForTesting
  final List<bool> played = [];

  AudioPlayer? _warningPlayer;
  AudioPlayer? _cautionPlayer;

  @override
  bool build() {
    _load();
    ref.listen(liveAlertsProvider, (_, next) => _onAlerts(next));
    // Repeats must fire even when no new telemetry frame changes the list.
    _repeatTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => _checkRepeats(DateTime.now()),
    );
    ref.onDispose(() {
      _repeatTimer?.cancel();
      _warningPlayer?.dispose();
      _cautionPlayer?.dispose();
    });
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(_prefKey);
    if (saved != null) state = saved;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, enabled);
  }

  void _onAlerts(List<LiveAlert> alerts) {
    final now = DateTime.now();
    final fresh = <LiveAlert>[];
    for (final a in alerts) {
      final last = _lastSeen[a.text];
      final wasActive = _active.contains(a.text);
      if (!wasActive && (last == null || now.difference(last) > _rearmAfter)) {
        fresh.add(a);
      }
      _lastSeen[a.text] = now;
    }
    _active = {for (final a in alerts) a.text};
    _lastChimed.removeWhere((text, _) => !_active.contains(text));
    _silencedUntil.removeWhere((text, _) => !_active.contains(text));
    _current = alerts;
    fresh.removeWhere((a) => _isSilenced(a.text, now));
    if (fresh.isNotEmpty) {
      for (final a in fresh) {
        _lastChimed[a.text] = now;
      }
      _chime(critical: fresh.any((a) => a.critical));
    }
    _checkRepeats(now);
  }

  /// Re-chimes active repeating alerts whose interval has elapsed.
  @visibleForTesting
  void checkRepeatsAt(DateTime now) => _checkRepeats(now);

  void _checkRepeats(DateTime now) {
    final due = [
      for (final a in _current)
        if (a.repeatEvery != null &&
            _lastChimed[a.text] != null &&
            now.difference(_lastChimed[a.text]!) >= a.repeatEvery!)
          a,
      // A silenced alert that is still active when its 10 s are up chimes
      // again straight away (and resumes its repeat cadence).
      for (final a in _current)
        if (_silencedUntil[a.text] != null &&
            !now.isBefore(_silencedUntil[a.text]!))
          a,
    ].where((a) => !_isSilenced(a.text, now)).toList();
    for (final a in due) {
      _silencedUntil.remove(a.text);
    }
    if (due.isEmpty) return;
    for (final a in due) {
      _lastChimed[a.text] = now;
    }
    _chime(critical: due.any((a) => a.critical));
  }

  bool _isSilenced(String text, DateTime now) {
    final until = _silencedUntil[text];
    return until != null && now.isBefore(until);
  }

  /// Tap-to-silence: mutes [text] for [silenceFor] (this device only).
  void silence(String text, {DateTime? now}) {
    _silencedUntil[text] = (now ?? DateTime.now()).add(silenceFor);
    _warningPlayer?.stop();
    _cautionPlayer?.stop();
  }

  void _chime({required bool critical}) {
    if (!state) return;
    _play(critical: critical);
  }

  Future<void> _play({required bool critical}) async {
    played.add(critical);
    // No audio plugin under `flutter test` (creating a player would throw
    // from a background future).
    if (!kIsWeb && Platform.environment.containsKey('FLUTTER_TEST')) return;
    try {
      final player = critical
          ? (_warningPlayer ??= AudioPlayer())
          : (_cautionPlayer ??= AudioPlayer());
      await player.stop();
      await player.play(
        AssetSource(critical ? 'sounds/warning.wav' : 'sounds/caution.wav'),
      );
    } catch (e) {
      // No audio device / plugin unavailable (e.g. tests) -- stay silent.
      debugPrint('Alert chime failed: $e');
    }
  }

  /// Plays a chime on demand (used by the settings "test" button).
  Future<void> preview({required bool critical}) => _play(critical: critical);
}

final alertChimeProvider = NotifierProvider<AlertChimeNotifier, bool>(
  AlertChimeNotifier.new,
);
