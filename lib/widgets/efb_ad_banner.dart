import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';
import '../core/app_links.dart';
import 'efb_flat_card.dart';

class EfbAdBanner extends StatefulWidget {
  const EfbAdBanner({super.key});

  @override
  State<EfbAdBanner> createState() => _EfbAdBannerState();
}

class _EfbAdBannerState extends State<EfbAdBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;

  final String _adUnitId = kReleaseMode
      ? 'ca-app-pub-3940256099942544/6300978111'
      : 'ca-app-pub-3940256099942544/6300978111';

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
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colors.dividerStrong, width: 1.5),
        ),
        title: Text(
          'SUPPORT CONCORDE EFB',
          textAlign: TextAlign.center,
          style: uiText(
            context,
            color: colors.textPrimary,
            weight: FontWeight.w900,
            size: 16,
            letterSpacing: 1.5,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Thank you for using Concorde EFB! If you find this tool helpful, consider supporting its active development.',
              textAlign: TextAlign.center,
              style: uiText(
                context,
                color: colors.textSecondary,
                size: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
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
                style: uiText(
                  context,
                  weight: FontWeight.bold,
                  color: Colors.white,
                  size: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.accent,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: colors.dividerStrong),
            const SizedBox(height: 16),
            Text(
              'Support via UPI',
              style: uiText(
                context,
                weight: FontWeight.bold,
                color: colors.textPrimary,
                size: 14,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colors.dividerStrong),
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
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(const ClipboardData(text: 'dwaipayanray95@ptaxis'));
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'UPI ID dwaipayanray95@ptaxis copied to clipboard!',
                        style: uiText(context, color: colors.textPrimary),
                      ),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: colors.surface,
                    ),
                  );
                }
              },
              icon: Icon(Icons.copy, color: colors.accent, size: 18),
              label: Text(
                'Copy UPI ID (dwaipayanray95@ptaxis)',
                style: uiText(
                  context,
                  weight: FontWeight.bold,
                  color: colors.accent,
                  size: 13,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colors.accent, width: 1.5),
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
              style: uiText(
                context,
                color: colors.textDim,
                weight: FontWeight.bold,
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
    final colors = context.colors;
    final isDesktopOrWeb = kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.linux;

    if (isDesktopOrWeb) {
      return Center(
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _showDonateDialog(context),
            child: Container(
              margin: const EdgeInsets.only(top: 24),
              width: 728,
              height: 90,
              child: EfbFlatCard(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.favorite, color: colors.departure, size: 28),
                        const SizedBox(width: 16),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'SUPPORT CONCORDE EFB DEVELOPMENT',
                              style: uiText(
                                context,
                                size: 12,
                                weight: FontWeight.w900,
                                color: colors.textPrimary,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Help keep this flight planner free and updated by sponsoring or donating.',
                              style: uiText(
                                context,
                                size: 11,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: colors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: colors.accent, width: 1.5),
                      ),
                      child: Text(
                        'DONATE NOW',
                        style: uiText(
                          context,
                          size: 11,
                          weight: FontWeight.bold,
                          color: colors.accent,
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
      );
    }

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
