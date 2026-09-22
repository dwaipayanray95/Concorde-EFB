import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/app_colors.dart';
import '../core/ui_text.dart';
import '../core/app_links.dart';
import '../core/app_version.dart';
import '../core/sim_bridge_launcher.dart';
import '../providers/efb_providers.dart';
import '../features/flight_monitor/presentation/controllers/telemetry_provider.dart';

/// Authentic cockpit-style vertical navigation rail for landscape tablet EFB.
class EfbNavRail extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const EfbNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final themeMode = ref.watch(themeModeProvider);
    final monitorState = ref.watch(flightMonitorProvider);
    final bridgeStatus = SimBridgeLauncher.status.value;

    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(
          right: BorderSide(
            color: colors.dividerStrong.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Aircraft badge / App icon
            Tooltip(
              message: 'Concorde EFB ${AppVersion.display}',
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colors.resultsBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: colors.dividerStrong.withValues(alpha: 0.8),
                    width: 1.2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/app-icon.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.airplanemode_active,
                      color: colors.accent,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Divider(
              color: colors.dividerStrong.withValues(alpha: 0.4),
              height: 1,
              indent: 14,
              endIndent: 14,
            ),
            const SizedBox(height: 16),

            // Navigation Items
            _NavRailItem(
              icon: Icons.flight_takeoff,
              label: 'PLAN',
              isSelected: selectedIndex == 0,
              onTap: () => onDestinationSelected(0),
            ),
            const SizedBox(height: 12),
            _NavRailItem(
              icon: Icons.playlist_add_check,
              label: 'CHECK',
              isSelected: selectedIndex == 1,
              onTap: () => onDestinationSelected(1),
            ),
            const SizedBox(height: 12),
            _NavRailItem(
              icon: Icons.monitor_heart,
              label: 'MONITOR',
              isSelected: selectedIndex == 2,
              onTap: () => onDestinationSelected(2),
            ),

            const Spacer(),

            // SimConnect status indicator
            _buildBridgeStatusIndicator(context, monitorState.isConnected, bridgeStatus),
            const SizedBox(height: 8),

            // Theme toggle
            Tooltip(
              message: themeMode == ThemeMode.dark ? 'Light mode' : 'Dark mode',
              child: IconButton(
                icon: Icon(
                  themeMode == ThemeMode.dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                  color: colors.textSecondary,
                  size: 20,
                ),
                onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
              ),
            ),

            // Utility / Settings menu
            Tooltip(
              message: 'EFB Settings & Links',
              child: IconButton(
                icon: Icon(
                  Icons.settings_outlined,
                  color: colors.textSecondary,
                  size: 20,
                ),
                onPressed: () => _showSettingsDialog(context),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _buildBridgeStatusIndicator(BuildContext context, bool isConnected, SimBridgeStatus? bridgeStatus) {
    final colors = context.colors;
    Color dotColor;
    String tooltipMsg;

    if (isConnected) {
      dotColor = colors.arrival; // Green
      tooltipMsg = 'SimConnect Telemetry Online';
    } else if (bridgeStatus == SimBridgeStatus.started || bridgeStatus == SimBridgeStatus.alreadyRunning) {
      dotColor = colors.mvfr; // Amber
      tooltipMsg = 'Bridge Running • Waiting on MSFS SimConnect';
    } else {
      dotColor = colors.textDim;
      tooltipMsg = 'Telemetry Disconnected';
    }

    return Tooltip(
      message: tooltipMsg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: dotColor,
                boxShadow: isConnected
                    ? [
                        BoxShadow(
                          color: dotColor.withValues(alpha: 0.6),
                          blurRadius: 6,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    final colors = context.colors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.dividerStrong, width: 1.5),
        ),
        title: Row(
          children: [
            Icon(Icons.tune, color: colors.accent, size: 20),
            const SizedBox(width: 10),
            Text(
              'CONCORDE EFB SETTINGS',
              style: uiText(
                context,
                weight: FontWeight.w900,
                size: 15,
                color: colors.textPrimary,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Version ${AppVersion.display}',
              style: uiText(context, size: 12, color: colors.textDim),
            ),
            const SizedBox(height: 16),
            _SettingButton(
              icon: Icons.history,
              label: 'View Changelog',
              url: AppLinks.changelog,
            ),
            const SizedBox(height: 8),
            _SettingButton(
              svgAsset: 'assets/discord_icon.svg',
              label: 'Join Discord Community',
              url: AppLinks.discord,
            ),
            const SizedBox(height: 8),
            _SettingButton(
              icon: Icons.star_border,
              label: 'Rate on Flightsim.to',
              url: AppLinks.flightsimTo,
            ),
            const SizedBox(height: 8),
            _SettingButton(
              icon: Icons.favorite_border,
              label: 'Support Development',
              url: AppLinks.donate,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'CLOSE',
              style: uiText(context, weight: FontWeight.bold, color: colors.accent),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavRailItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavRailItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final activeBg = colors.accent.withValues(alpha: 0.16);
    final activeBorder = colors.accent;
    final inactiveBorder = Colors.transparent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          hoverColor: colors.resultsBg.withValues(alpha: 0.5),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? activeBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? activeBorder : inactiveBorder,
                width: 1.2,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: isSelected ? colors.accent : colors.textSecondary,
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: uiText(
                    context,
                    size: 9.5,
                    weight: isSelected ? FontWeight.w900 : FontWeight.w600,
                    color: isSelected ? colors.accent : colors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingButton extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final String label;
  final String url;

  const _SettingButton({
    this.icon,
    this.svgAsset,
    required this.label,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {
          try {
            await launchUrl(uri);
          } catch (_) {}
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.inputBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            if (icon != null)
              Icon(icon, size: 16, color: colors.accent)
            else if (svgAsset != null)
              SvgPicture.asset(
                svgAsset!,
                width: 16,
                height: 16,
                colorFilter: ColorFilter.mode(colors.accent, BlendMode.srcIn),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: uiText(context, size: 12, weight: FontWeight.w600, color: colors.textPrimary),
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: colors.textDim),
          ],
        ),
      ),
    );
  }
}
