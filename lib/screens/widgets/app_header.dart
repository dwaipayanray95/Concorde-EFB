import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../../core/app_links.dart';
import '../../providers/efb_providers.dart';

/// App title/logo row with an optional [trailing] widget (the nav tab
/// selector lives here, passed in by home_screen, so it shares this row
/// instead of eating a separate one) and, when [hasUpdate] is true, an
/// "update available" banner above it.
class AppHeader extends ConsumerWidget {
  final bool hasUpdate;
  final String? latestVersion;
  final Widget? trailing;

  const AppHeader({
    super.key,
    required this.hasUpdate,
    this.latestVersion,
    this.trailing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasUpdate && latestVersion != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.35),
                width: 1.5,
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.accent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A NEW UPDATE IS AVAILABLE',
                        style: uiText(
                          context,
                          weight: FontWeight.w900,
                          size: 12,
                          color: colors.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version v$latestVersion is now ready. Download it from flightsim.to to get the latest features.',
                        style: uiText(context, size: 13, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse(AppLinks.flightsimTo);
                    try {
                      await launchUrl(url);
                    } catch (_) {}
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    'DOWNLOAD NOW',
                    style: uiText(
                      context,
                      weight: FontWeight.bold,
                      size: 11,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: colors.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: colors.textPrimary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/app-icon.png',
                  width: 64,
                  height: 64,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.airplanemode_active,
                    color: colors.accent,
                    size: 64,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CONCORDE EFB',
                    style: uiText(
                      context,
                      size: 28,
                      weight: FontWeight.w900,
                      color: colors.textPrimary,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your supersonic co-pilot for Microsoft Flight Simulator.',
                    style: uiText(
                      context,
                      size: 13,
                      weight: FontWeight.w500,
                      color: colors.textSecondary,
                    ).copyWith(fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: themeMode == ThemeMode.dark
                  ? 'Switch to light mode'
                  : 'Switch to dark mode',
              child: IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark
                      ? Icons.light_mode
                      : Icons.dark_mode,
                  color: colors.accent,
                  size: 20,
                ),
                onPressed: () {
                  ref.read(themeModeProvider.notifier).toggle();
                },
              ),
            ),
            Tooltip(
              message: 'Click to support',
              child: IconButton(
                icon: Icon(Icons.favorite, color: colors.departure, size: 20),
                onPressed: () async {
                  final url = Uri.parse(AppLinks.changelog);
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    try {
                      await launchUrl(url);
                    } catch (_) {}
                  }
                },
              ),
            ),
            Tooltip(
              message: 'Join our Discord',
              child: IconButton(
                icon: SvgPicture.asset(
                  'assets/discord_icon.svg',
                  width: 20,
                  height: 20,
                  colorFilter: ColorFilter.mode(colors.accent, BlendMode.srcIn),
                ),
                onPressed: () async {
                  final url = Uri.parse(AppLinks.discord);
                  try {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  } catch (_) {
                    try {
                      await launchUrl(url);
                    } catch (_) {}
                  }
                },
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 16), trailing!],
          ],
        ),
      ],
    );
  }
}
