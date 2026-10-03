import 'package:flutter/material.dart';
import '../../services/ad_consent_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../../core/app_links.dart';
import '../../widgets/efb_launches_badge.dart';
import '../../widgets/efb_ad_banner.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: the support-development banner alongside a matching card
/// of cockpit-style softkey links (launches count, changelog, Discord, GitHub
/// Sponsors), laid out side by side with responsive stacking fallback.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 1000;
        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                const EfbAdBanner(),
                const SizedBox(height: 12),
                _buildLinksCard(context),
                const SizedBox(height: 16),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 12),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Expanded(child: EfbAdBanner()),
                    const SizedBox(width: 14),
                    _buildLinksCard(context),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLinksCard(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colors.dividerStrong.withValues(alpha: 0.7),
          width: 1.2,
        ),
      ),
      // Wrap (not Row) so the extra privacy buttons can't overflow narrow
      // phone widths.
      child: ValueListenableBuilder<bool>(
        valueListenable: AdConsentService.privacyOptionsRequired,
        builder: (context, showAdPrivacy, _) => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const EfbLaunchesBadge(),
            _FooterLinkButton(
              icon: Icons.history,
              label: 'VIEW CHANGELOG',
              url: AppLinks.changelog,
            ),
            _FooterLinkButton(
              icon: Icons.forum_outlined,
              label: 'JOIN DISCORD',
              url: AppLinks.discord,
            ),
            _FooterLinkButton(
              icon: Icons.favorite_border,
              label: 'GITHUB SPONSOR',
              url: AppLinks.githubSponsors,
            ),
            _FooterLinkButton(
              icon: Icons.privacy_tip_outlined,
              label: 'PRIVACY',
              url: AppLinks.privacy,
            ),
            // Only shown where UMP requires it (EEA/UK/CH users on mobile):
            // lets the user change or withdraw ad consent at any time.
            if (showAdPrivacy)
              _FooterLinkButton(
                icon: Icons.tune,
                label: 'AD PRIVACY OPTIONS',
                onTap: AdConsentService.showPrivacyOptions,
              ),
          ],
        ),
      ),
    );
  }
}

/// A cockpit MFD segmented softkey button for footer links.
/// Matches the 6px radius, anodized bezel, and amber interactive illumination.
class _FooterLinkButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final String? url;
  final Future<void> Function()? onTap;

  const _FooterLinkButton({
    this.icon,
    required this.label,
    this.url,
    this.onTap,
  });

  @override
  State<_FooterLinkButton> createState() => _FooterLinkButtonState();
}

class _FooterLinkButtonState extends State<_FooterLinkButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: () async {
          if (widget.onTap != null) {
            await widget.onTap!();
            return;
          }
          try {
            await launchUrl(Uri.parse(widget.url!));
          } catch (_) {}
        },
        borderRadius: BorderRadius.circular(6),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: _isHovered
                ? colors.accent.withValues(alpha: 0.15)
                : colors.resultsBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: _isHovered
                  ? colors.accent
                  : colors.dividerStrong.withValues(alpha: 0.8),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 13,
                  color: _isHovered ? colors.accent : colors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: uiText(
                  context,
                  color: _isHovered ? colors.accent : colors.textPrimary,
                  size: 10,
                  weight: FontWeight.w800,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
