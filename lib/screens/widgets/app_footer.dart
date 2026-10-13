import 'package:flutter/material.dart';
import '../../widgets/efb_ad_banner.dart';
import '../../widgets/efb_launches_badge.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: the support-development card (ad banner on mobile) with the
/// EFB launches counter underneath.
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    // The old links strip (changelog, Discord, sponsor) stays out -- those
    // live in the Settings menu. The launches counter is the one thing that
    // comes back. Fetching it (visitorCountProvider) is what bumps the count,
    // once per app session, so it must be built whenever the footer is.
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          EfbAdBanner(),
          SizedBox(height: 10),
          Align(alignment: Alignment.center, child: EfbLaunchesBadge()),
        ],
      ),
    );
  }
}
