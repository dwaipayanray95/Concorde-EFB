import 'package:flutter/material.dart';
import '../../../../../core/app_colors.dart';
import '../../../../../core/sim_bridge_launcher.dart';
import '../../../../../core/ui_text.dart';
import '../../../data/models/telemetry_model.dart';

/// Top status/controls bar: connection dot + Zulu clock.
class FmToolbar extends StatelessWidget {
  final bool isConnected;
  final TelemetryModel telemetry;

  const FmToolbar({
    super.key,
    required this.isConnected,
    required this.telemetry,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final statusColor = isConnected ? colors.arrival : colors.error;
    final statusLabel = isConnected
        ? 'SIMCONNECT BRIDGE CONNECTED'
        : 'DISCONNECTED';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
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
              const SizedBox(width: 12),
              Text(
                statusLabel,
                style: uiText(
                  context,
                  size: 12,
                  color: statusColor,
                  weight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
              if (!isConnected) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: ValueListenableBuilder<SimBridgeStatus?>(
                    valueListenable: SimBridgeLauncher.status,
                    builder: (context, bridgeStatus, _) {
                      final detail = switch (bridgeStatus) {
                        SimBridgeStatus.exeNotFound =>
                          'BRIDGE EXE MISSING — CHECK ANTIVIRUS QUARANTINE',
                        SimBridgeStatus.launchFailed =>
                          'BRIDGE FAILED TO LAUNCH — ${SimBridgeLauncher.lastError ?? "unknown error"}',
                        SimBridgeStatus.started ||
                        SimBridgeStatus.alreadyRunning =>
                          'BRIDGE RUNNING — WAITING FOR MSFS SIMCONNECT',
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
                ),
              ],
              const SizedBox(width: 8),
              Container(
                width: 1,
                height: 16,
                color: colors.dividerStrong,
                margin: const EdgeInsets.symmetric(horizontal: 4),
              ),
              Text(
                '${telemetry.zuluTime}Z',
                style: uiText(context, size: 12, color: colors.textDim),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
