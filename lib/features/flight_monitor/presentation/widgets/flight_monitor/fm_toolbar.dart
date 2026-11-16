import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/sim_bridge_launcher.dart';
import '../../../../../core/ui_text.dart';
import '../../../data/models/telemetry_model.dart';
import '../../../data/services/lan_link.dart';
import 'wifi_link_card.dart';

/// Top status/controls bar: connection dot, live status, Zulu clock,
/// and inline Wi-Fi connection pairing controls.
class FmToolbar extends StatelessWidget {
  final bool isConnected;
  final TelemetryModel telemetry;

  /// Live explanation from the bridge (e.g. "Waiting for MSFS"), if reachable.
  final String? bridgeMessage;

  const FmToolbar({
    super.key,
    required this.isConnected,
    required this.telemetry,
    this.bridgeMessage,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = isConnected ? colors.arrival : colors.error;
    final statusLabel = isConnected
        ? (isRemoteClientPlatform ? 'LIVE FROM SIM PC' : 'SIMCONNECT BRIDGE CONNECTED')
        : 'DISCONNECTED';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left side: Connection status dot + label + bridge message + Zulu clock
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.6),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              statusLabel,
              style: uiText(
                context,
                size: 11,
                color: statusColor,
                weight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            if (!isConnected) ...[
              const SizedBox(width: 6),
              ValueListenableBuilder<SimBridgeStatus?>(
                valueListenable: SimBridgeLauncher.status,
                builder: (context, bridgeStatus, _) {
                  final detail = switch (bridgeStatus) {
                    SimBridgeStatus.exeNotFound =>
                      'BRIDGE EXE MISSING',
                    SimBridgeStatus.launchFailed =>
                      'BRIDGE FAILED TO LAUNCH',
                    _ when bridgeMessage != null &&
                            bridgeMessage!.isNotEmpty =>
                      bridgeMessage!.toUpperCase(),
                    SimBridgeStatus.started ||
                    SimBridgeStatus.alreadyRunning =>
                      'STARTING BRIDGE…',
                    _ => null,
                  };
                  if (detail == null) return const SizedBox.shrink();
                  return Text(
                    '· $detail',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: uiText(
                      context,
                      size: 10,
                      color: colors.textDim,
                      weight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  );
                },
              ),
            ],
            const SizedBox(width: 6),
            Container(
              width: 1,
              height: 14,
              color: colors.dividerStrong,
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            Text(
              '${telemetry.zuluTime}Z',
              style: uiText(context, size: 11, color: colors.textDim),
            ),
          ],
        ),

        const SizedBox(width: 12),

        // Right side: in line with connection status row!
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.hasBoundedWidth
                        ? constraints.maxWidth
                        : 0,
                  ),
                  child: const Align(
                    alignment: Alignment.centerRight,
                    child: WifiLinkCard(),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
