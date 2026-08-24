import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../../core/app_links.dart';
import '../../widgets/efb_launches_badge.dart';
import '../../widgets/efb_ad_banner.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: launches badge, disclaimer, changelog link, and ad banner.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [EfbLaunchesBadge()],
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            InkWell(
              onTap: () async {
                final url = Uri.parse(AppLinks.changelog);
                try {
                  await launchUrl(url);
                } catch (_) {}
              },
              borderRadius: BorderRadius.circular(4),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'VIEW CHANGELOG',
                  style: uiText(
                    context,
                    color: colors.accent,
                    size: 12,
                    weight: FontWeight.bold,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
            Text(
              '  •  ',
              style: uiText(context, color: colors.textDim, size: 12),
            ),
            InkWell(
              onTap: () async {
                final url = Uri.parse(AppLinks.discord);
                try {
                  await launchUrl(url);
                } catch (_) {}
              },
              borderRadius: BorderRadius.circular(4),
              mouseCursor: SystemMouseCursors.click,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(
                  'JOIN DISCORD',
                  style: uiText(
                    context,
                    color: colors.accent,
                    size: 12,
                    weight: FontWeight.bold,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ],
        ),
        const EfbAdBanner(),
      ],
    );
  }
}
