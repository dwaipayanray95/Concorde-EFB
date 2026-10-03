import 'package:flutter/material.dart';
import '../../widgets/efb_ad_banner.dart';

/// Shared footer shown at the bottom of the Flight Planner and Flight
/// Monitor tabs: the support-development card (ad banner on mobile).
class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    // Just the support card: the old links strip (launches, changelog,
    // Discord, sponsor) didn't line up with it and those links already live
    // in the Settings menu.
    return const Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 16),
      child: EfbAdBanner(),
    );
  }
}
