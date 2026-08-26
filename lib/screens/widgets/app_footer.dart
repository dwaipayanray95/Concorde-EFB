import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../../core/app_links.dart';
import '../../widgets/efb_launches_badge.dart';
import '../../widgets/efb_ad_banner.dart';
import '../../widgets/efb_flat_card.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: the support-development banner alongside a matching card
/// of pill-shaped link buttons (launches count, changelog, Discord, GitHub
/// Sponsors), laid out side by side.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      children: [
        const SizedBox(height: 8),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(width: 24),
              const Expanded(child: EfbAdBanner()),
              const SizedBox(width: 20),
              EfbFlatCard(
                background: colors.resultsBg,
                padding: const EdgeInsets.all(16),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const EfbLaunchesBadge(),
                    const SizedBox(width: 12),
                    _FooterLinkButton(
                      label: 'VIEW CHANGELOG',
                      url: AppLinks.changelog,
                    ),
                    const SizedBox(width: 12),
                    _FooterLinkButton(
                      label: 'JOIN DISCORD',
                      url: AppLinks.discord,
                    ),
                    const SizedBox(width: 12),
                    _FooterLinkButton(
                      label: 'GITHUB SPONSOR',
                      url: AppLinks.githubSponsors,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A pill-shaped footer link button, matching the support banner's
/// "DONATE NOW" style so the whole group reads as one button family.
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
      borderRadius: BorderRadius.circular(20),
      mouseCursor: SystemMouseCursors.click,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: colors.accent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.accent, width: 1.5),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: uiText(
            context,
            color: colors.accent,
            size: 11,
            weight: FontWeight.bold,
            letterSpacing: 0.8,
          ),
        ),
      ),
    );
  }
}
