import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'live_alerts_provider.dart';

/// Plays ONE chime when a live alert first appears -- not a repeating
/// master-caution loop:
///  - red warning  -> two-tone chime (assets/sounds/warning.wav)
///  - amber caution -> single soft chime (assets/sounds/caution.wav)
/// If several alerts appear at once, only the most severe chime plays.
/// An alert that blinks off and back on within [_rearmAfter] doesn't
/// re-chime (e.g. DESCEND NOW flickering at its threshold).
///
/// State = chimes enabled (persisted). Watched from HomeScreen so it runs
/// whichever tab is open.
class AlertChimeNotifier extends Notifier<bool> {
  static const _prefKey = 'alert_chimes_enabled';
  static const _rearmAfter = Duration(seconds: 10);

  final Map<String, DateTime> _lastSeen = {};
  Set<String> _active = {};

  /// Severity of every chime played (true = warning), for tests.
  @visibleForTesting
  final List<bool> played = [];

  AudioPlayer? _warningPlayer;
  AudioPlayer? _cautionPlayer;

  @override
  bool build() {
    _load();
    ref.listen(liveAlertsProvider, (_, next) => _onAlerts(next));
    ref.onDispose(() {
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
    if (!state || fresh.isEmpty) return;
    _play(critical: fresh.any((a) => a.critical));
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
