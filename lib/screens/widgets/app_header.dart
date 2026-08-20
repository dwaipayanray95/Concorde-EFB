import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/ui_tokens.dart';
import '../../core/app_links.dart';

/// App title/logo row with an optional [trailing] widget (the nav tab
/// selector lives here, passed in by home_screen, so it shares this row
/// instead of eating a separate one) and, when [hasUpdate] is true, an
/// "update available" banner above it.
class AppHeader extends StatelessWidget {
  final bool hasUpdate;
  final String? latestVersion;
  final Widget? trailing;

  const AppHeader({super.key, required this.hasUpdate, this.latestVersion, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasUpdate && latestVersion != null) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: UiTokens.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: UiTokens.accent.withValues(alpha: 0.4), width: 1.5),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: UiTokens.accent, size: 24),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'A NEW UPDATE IS AVAILABLE',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          color: UiTokens.accent,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Version v$latestVersion is now ready. Download it from flightsim.to to get the latest features.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: Colors.white,
                        ),
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
                    backgroundColor: UiTokens.accent,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    'DOWNLOAD NOW',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
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
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: UiTokens.accent.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: -5)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('assets/app-icon.png', width: 64, height: 64, errorBuilder: (context, error, stackTrace) => const Icon(Icons.airplanemode_active, color: UiTokens.accent, size: 64)),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Concorde EFB',
                    style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Flight planning & performance for MSFS.',
                    style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w500, color: UiTokens.textSecondary),
                  ),
                ],
              ),
            ),
            Tooltip(
              message: 'Click to support',
              child: IconButton(
                icon: const Icon(Icons.favorite, color: UiTokens.accent, size: 20),
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
            if (trailing != null) ...[
              const SizedBox(width: 16),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}
