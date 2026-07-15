import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui_tokens.dart';
import '../../widgets/efb_launches_badge.dart';
import '../../widgets/efb_ad_banner.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: launches badge, disclaimer, changelog link, and ad banner.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 20),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            EfbLaunchesBadge(),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Speeds scale with √(weight/reference) and are indicative IAS; verify against the DC Designs manual & in-sim.',
          style: GoogleFonts.plusJakartaSans(color: UiTokens.textDim, fontSize: 12),
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () async {
            final url = Uri.parse('https://dwaipayanray95.github.io/Concorde-EFB/changelog/');
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
              style: GoogleFonts.plusJakartaSans(
                color: UiTokens.accent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const EfbAdBanner(),
      ],
    );
  }
}
