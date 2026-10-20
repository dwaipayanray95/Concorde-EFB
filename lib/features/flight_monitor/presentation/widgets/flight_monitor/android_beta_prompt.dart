import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../core/app_colors.dart';
import '../../../../../core/app_links.dart';
import '../../../../../core/ui_text.dart';
import '../../../data/services/lan_link.dart';

/// "Now on Android -- join the internal test" prompt, shown on the Flight
/// Monitor tab of the desktop app (phones/tablets already have the app).
///
/// Rules ([AndroidBetaPromptPolicy]):
///  - at most once per app launch, the first time the Monitor tab opens;
///  - REMIND ME NEXT LAUNCH: just closes, it shows again next launch;
///  - REMIND ME LATER: hidden for [AndroidBetaPromptPolicy.snoozeFor];
///  - NEVER: hidden for good;
///  - JOIN THE TEST: shows the links and counts as "never" (the links stay
///    reachable from the Share card's Android button).
class AndroidBetaPromptPolicy {
  AndroidBetaPromptPolicy._();

  static const prefNever = 'android_beta_prompt_never';
  static const prefSnoozeUntil = 'android_beta_prompt_snooze_until';
  static const snoozeFor = Duration(days: 3);

  static bool _shownThisSession = false;

  @visibleForTesting
  static void resetSession() => _shownThisSession = false;

  /// Desktop only: phones/tablets already run the Android app.
  static bool get platformEligible => !kIsWeb && !isMobilePlatform;

  static bool shouldShow(SharedPreferences prefs, {DateTime? now}) {
    if (_shownThisSession) return false;
    if (prefs.getBool(prefNever) ?? false) return false;
    final until = prefs.getInt(prefSnoozeUntil);
    if (until != null &&
        (now ?? DateTime.now()).millisecondsSinceEpoch < until) {
      return false;
    }
    return true;
  }

  static void markShown() => _shownThisSession = true;

  static Future<void> never(SharedPreferences prefs) =>
      prefs.setBool(prefNever, true);

  static Future<void> snooze(SharedPreferences prefs, {DateTime? now}) =>
      prefs.setInt(
        prefSnoozeUntil,
        (now ?? DateTime.now()).add(snoozeFor).millisecondsSinceEpoch,
      );
}

/// Call once the Monitor tab is on screen. Does nothing when the prompt
/// shouldn't show (see [AndroidBetaPromptPolicy]).
Future<void> maybeShowAndroidBetaPrompt(BuildContext context) async {
  if (!AndroidBetaPromptPolicy.platformEligible) return;
  final SharedPreferences prefs;
  try {
    prefs = await SharedPreferences.getInstance();
  } catch (_) {
    return;
  }
  if (!context.mounted || !AndroidBetaPromptPolicy.shouldShow(prefs)) return;
  AndroidBetaPromptPolicy.markShown();
  await showAndroidBetaDialog(context, fromPrompt: true);
}

/// The dialog itself. [fromPrompt] = the automatic prompt (pitch + reminder
/// choices first); otherwise it opens straight on the links.
Future<void> showAndroidBetaDialog(
  BuildContext context, {
  bool fromPrompt = false,
}) => showDialog<void>(
  context: context,
  barrierDismissible: !fromPrompt,
  builder: (_) => _AndroidBetaDialog(fromPrompt: fromPrompt),
);

class _AndroidBetaDialog extends StatefulWidget {
  final bool fromPrompt;
  const _AndroidBetaDialog({required this.fromPrompt});

  @override
  State<_AndroidBetaDialog> createState() => _AndroidBetaDialogState();
}

class _AndroidBetaDialogState extends State<_AndroidBetaDialog> {
  late bool _showLinks = !widget.fromPrompt;

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      try {
        await launchUrl(uri);
      } catch (_) {}
    }
  }

  Future<void> _remember(
    Future<void> Function(SharedPreferences prefs) save,
  ) async {
    try {
      await save(await SharedPreferences.getInstance());
    } catch (_) {}
  }

  void _close() => Navigator.of(context).pop();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return AlertDialog(
      backgroundColor: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.dividerStrong, width: 1.5),
      ),
      title: Row(
        children: [
          Icon(Icons.android, color: colors.accent, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _showLinks ? 'JOIN THE ANDROID TEST' : 'NOW ON ANDROID',
              style: uiText(
                context,
                color: colors.textPrimary,
                weight: FontWeight.w900,
                size: 15,
                letterSpacing: 1.4,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: _showLinks ? _links(context) : _pitch(context),
        ),
      ),
      actionsOverflowButtonSpacing: 4,
      actions: _showLinks ? _linkActions(context) : _pitchActions(context),
    );
  }

  Widget _pitch(BuildContext context) {
    final colors = context.colors;
    return Text(
      'Concorde EFB is now available for Android phones and tablets. Put the '
      'Flight Monitor on a tablet next to your screen -- it shows live data '
      'from this PC over Wi-Fi.\n\n'
      'It is in internal testing: join the tester group to get the app and '
      'help us shape it.',
      style: uiText(context, color: colors.textSecondary, size: 12.5, height: 1.5),
    );
  }

  List<Widget> _pitchActions(BuildContext context) {
    final colors = context.colors;
    Widget text(String label, VoidCallback onTap, {Color? color}) => TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: uiText(
          context,
          color: color ?? colors.textDim,
          weight: FontWeight.w800,
          size: 10.5,
          letterSpacing: 0.6,
        ),
      ),
    );
    return [
      text('NEVER', () async {
        await _remember(AndroidBetaPromptPolicy.never);
        if (mounted) _close();
      }),
      text('REMIND ME LATER', () async {
        await _remember(AndroidBetaPromptPolicy.snooze);
        if (mounted) _close();
      }),
      text('NEXT LAUNCH', _close),
      ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: AppColors.dark.bg,
        ),
        onPressed: () async {
          // They've seen the steps -- don't nag again.
          await _remember(AndroidBetaPromptPolicy.never);
          if (mounted) setState(() => _showLinks = true);
        },
        child: Text(
          'JOIN THE TEST',
          style: uiText(
            context,
            color: AppColors.dark.bg,
            weight: FontWeight.w900,
            size: 11,
          ),
        ),
      ),
    ];
  }

  Widget _links(BuildContext context) {
    final colors = context.colors;
    Widget step(int n, String title, String sub, String url) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: colors.accent,
            child: Text(
              '$n',
              style: uiText(
                context,
                color: AppColors.dark.bg,
                weight: FontWeight.w900,
                size: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: uiText(
                    context,
                    color: colors.textPrimary,
                    weight: FontWeight.w800,
                    size: 12,
                  ),
                ),
                Text(
                  sub,
                  style: uiText(
                    context,
                    color: colors.textDim,
                    size: 10.5,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: colors.accent, width: 1.2),
            ),
            onPressed: () => _open(url),
            child: Text(
              'OPEN',
              style: uiText(
                context,
                color: colors.accent,
                weight: FontWeight.w900,
                size: 10.5,
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Do these in order, signed in to the Google account you use on your '
          'Android device:',
          style: uiText(
            context,
            color: colors.textSecondary,
            size: 12,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        step(
          1,
          'Join the testers group',
          'Gives your Google account access to the test.',
          AppLinks.androidTestersGroup,
        ),
        step(
          2,
          'Become a tester',
          'Opt in on the Google Play testing page.',
          AppLinks.androidTestOptIn,
        ),
        step(
          3,
          'Install from Google Play',
          'Opens the Concorde EFB listing on your device.',
          AppLinks.androidPlayStore,
        ),
        Divider(color: colors.dividerStrong),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                'Questions or feedback? Come say hi on Discord.',
                style: uiText(
                  context,
                  color: colors.textDim,
                  size: 10.5,
                  height: 1.3,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _open(AppLinks.discord),
              child: Text(
                'DISCORD',
                style: uiText(
                  context,
                  color: colors.accent,
                  weight: FontWeight.w900,
                  size: 10.5,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<Widget> _linkActions(BuildContext context) => [
    TextButton(
      onPressed: _close,
      child: Text(
        'CLOSE',
        style: uiText(
          context,
          color: context.colors.textDim,
          weight: FontWeight.w800,
          size: 11,
        ),
      ),
    ),
  ];
}
