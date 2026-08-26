import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../../core/app_links.dart';
import '../../widgets/efb_launches_badge.dart';
import '../../widgets/efb_ad_banner.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: the support-development banner alongside a stack of
/// small link buttons (launches count, changelog, Discord).
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(width: 600, child: EfbAdBanner()),
            const SizedBox(width: 20),
            Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EfbLaunchesBadge(),
                const SizedBox(height: 10),
                _FooterLinkButton(
                  label: 'VIEW CHANGELOG',
                  url: AppLinks.changelog,
                ),
                const SizedBox(height: 10),
                _FooterLinkButton(label: 'JOIN DISCORD', url: AppLinks.discord),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// A small button-styled footer link, stacked alongside the launches badge.
class _FooterLinkButton extends StatelessWidget {
  final String label;
  final String url;

  const _FooterLinkButton({required this.label, required this.url});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri);
        } catch (_) {}
      },
      borderRadius: BorderRadius.circular(6),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.dividerStrong, width: 1),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: uiText(
            context,
            color: colors.accent,
            size: 10,
            weight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
