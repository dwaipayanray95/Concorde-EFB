import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/ui_tokens.dart';
import '../core/app_links.dart';
import 'efb_glass_container.dart';

class EfbAdBanner extends StatefulWidget {
  const EfbAdBanner({super.key});

  @override
  State<EfbAdBanner> createState() => _EfbAdBannerState();
}

class _EfbAdBannerState extends State<EfbAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  // Google Test Ad Unit ID for Android Banner Ads
  final String _adUnitId = kReleaseMode
      ? 'ca-app-pub-3940256099942544/6300978111' // Replace with your real AdMob Ad Unit ID in release mode
      : 'ca-app-pub-3940256099942544/6300978111'; // Standard Google Test Banner ID

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux) {
      // Ads not supported natively on Desktop/Web via AdMob package
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          setState(() {
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, err) {
          ad.dispose();
        },
      ),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  void _showDonateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A).withValues(alpha: 0.95), // Translucent slate dark
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
        ),
        title: Text(
          'SUPPORT CONCORDE EFB',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your contributions help keep this flight bag free and updated!',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: UiTokens.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            // Patreon Button
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(AppLinks.patreon);
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {
                  try {
                    await launchUrl(url);
                  } catch (_) {}
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.star, color: Colors.white, size: 20),
              label: Text(
                'Support on Patreon',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF424D), // Patreon Red/Coral
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),
            // Changelog Web Button
            ElevatedButton.icon(
              onPressed: () async {
                final url = Uri.parse(AppLinks.changelog);
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (_) {
                  try {
                    await launchUrl(url);
                  } catch (_) {}
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              icon: const Icon(Icons.history, color: Colors.white, size: 20),
              label: Text(
                'Click to Support (Web)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EA5E9), // Sky Blue Accent
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Text(
              'Support via UPI',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Image.network(
                'https://api.qrserver.com/v1/create-qr-code/?size=180x180&data=upi%3A%2F%2Fpay%3Fpa%3Ddwaipayanray95%40ptaxis%26pn%3DRay%26tn%3DConcorde%2520EFB%2520Support%26cu%3DINR',
                width: 150,
                height: 150,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    width: 150,
                    height: 150,
                    child: Center(
                      child: Icon(Icons.qr_code, color: Colors.black54, size: 48),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // UPI Copy Button
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'dwaipayanray95@ptaxis'));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'UPI ID dwaipayanray95@ptaxis copied to clipboard!',
                        style: GoogleFonts.plusJakartaSans(color: Colors.white),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: UiTokens.surface,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.copy, color: UiTokens.accent, size: 18),
              label: Text(
                'Copy UPI ID (dwaipayanray95@ptaxis)',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.bold,
                  color: UiTokens.accent,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: UiTokens.accent, width: 1.5),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CLOSE',
              style: GoogleFonts.plusJakartaSans(
                color: UiTokens.textDim,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktopOrWeb = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktopOrWeb) {
      // Renders a sleek custom glassmorphic banner for Desktop/Web users to sponsor or donate
      return Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showDonateDialog(context),
            child: Container(
              margin: const EdgeInsets.only(top: 24),
              width: 728,
              height: 90,
              child: EfbGlassContainer(
                blur: 15,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: UiTokens.accent.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.favorite, color: Colors.redAccent, size: 28),
                          const SizedBox(width: 16),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'SUPPORT CONCORDE EFB DEVELOPMENT',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Help keep this flight planner free and updated by sponsoring or donating.',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  color: UiTokens.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: UiTokens.accent.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: UiTokens.accent, width: 1.5),
                        ),
                        child: Text(
                          'DONATE NOW',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Renders the Google AdMob banner on Mobile (Android / iOS)
    if (_isLoaded && _bannerAd != null) {
      return Container(
        margin: const EdgeInsets.only(top: 24),
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      );
    }

    return const SizedBox.shrink();
  }
}
