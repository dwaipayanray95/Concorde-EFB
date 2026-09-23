import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/app_colors.dart';
import '../../core/ui_text.dart';
import '../../core/app_links.dart';
import '../../providers/efb_providers.dart';
import '../../features/flight_monitor/presentation/controllers/telemetry_provider.dart';
import '../../core/sim_bridge_launcher.dart';

/// Authentic cockpit-style operational status bar for landscape tablet EFB.
/// Displays aircraft tag, active route pill, live Zulu/UTC clock, and SimConnect link.
class CockpitStatusBar extends ConsumerStatefulWidget {
  final bool hasUpdate;
  final String? latestVersion;

  const CockpitStatusBar({
    super.key,
    required this.hasUpdate,
    this.latestVersion,
  });

  @override
  ConsumerState<CockpitStatusBar> createState() => _CockpitStatusBarState();
}

class _CockpitStatusBarState extends ConsumerState<CockpitStatusBar> {
  late Timer _clockTimer;
  DateTime _nowUtc = DateTime.now().toUtc();

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _nowUtc = DateTime.now().toUtc();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  String _formatZulu(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s Z';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final depIcao = ref.watch(departureIcaoProvider);
    final arrIcao = ref.watch(arrivalIcaoProvider);
    final plannedDistance = ref.watch(plannedDistanceProvider);
    final monitorState = ref.watch(flightMonitorProvider);
    final bridgeStatus = SimBridgeLauncher.status.value;
    final callSign = ref.watch(callSignProvider);
    final registration = ref.watch(registrationProvider);
    final paxCount = ref.watch(paxCountProvider);
    final simbriefLoaded = ref.watch(simbriefLoadedProvider);

    final hasRoute = depIcao.isNotEmpty && arrIcao.isNotEmpty;
    final isFlightLoaded = simbriefLoaded ||
        (callSign.isNotEmpty && callSign != '--') ||
        (registration.isNotEmpty && registration != '--');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.hasUpdate && widget.latestVersion != null)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: colors.accent.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colors.accent, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'UPDATE AVAILABLE: v${widget.latestVersion} is ready on flightsim.to',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.bold,
                      color: colors.accent,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final url = Uri.parse(AppLinks.flightsimTo);
                    try {
                      await launchUrl(url);
                    } catch (_) {}
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    'GET UPDATE',
                    style: uiText(
                      context,
                      size: 11,
                      weight: FontWeight.w900,
                      color: colors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.7),
              width: 1.2,
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flight Deck Identity: Call Sign, Reg, Pax
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeaderPill(
                      context,
                      label: 'CALL SIGN',
                      value: callSign,
                      isPopulated: callSign.isNotEmpty && callSign != '--',
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderPill(
                      context,
                      label: 'REG',
                      value: registration,
                      isPopulated: registration.isNotEmpty && registration != '--',
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderPill(
                      context,
                      label: 'PAX',
                      value: isFlightLoaded ? '$paxCount' : '--',
                      isPopulated: isFlightLoaded,
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Container(
                  width: 1,
                  height: 18,
                  color: colors.dividerStrong.withValues(alpha: 0.5),
                ),
                const SizedBox(width: 14),

                // Route pill
                Semantics(
                  label: hasRoute
                      ? 'Active route: $depIcao to $arrIcao, ${plannedDistance.round()} nautical miles'
                      : 'No active route set',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.resultsBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.dividerStrong.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hasRoute) ...[
                          Text(
                            depIcao,
                            style: uiText(
                              context,
                              size: 12,
                              weight: FontWeight.w900,
                              color: colors.departure,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(Icons.arrow_forward, size: 12, color: colors.textDim),
                          const SizedBox(width: 6),
                          Text(
                            arrIcao,
                            style: uiText(
                              context,
                              size: 12,
                              weight: FontWeight.w900,
                              color: colors.arrival,
                            ),
                          ),
                          if (plannedDistance > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• ${plannedDistance.round()} NM',
                              style: uiText(
                                context,
                                size: 11,
                                weight: FontWeight.w600,
                                color: colors.textDim,
                              ),
                            ),
                          ],
                        ] else ...[
                          Text(
                            'NO ACTIVE ROUTE',
                            style: uiText(
                              context,
                              size: 11,
                              weight: FontWeight.w700,
                              color: colors.textDim,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // SimConnect Status Pill
                _buildSimPill(context, monitorState.isConnected, bridgeStatus),
                const SizedBox(width: 12),

                // Live Zulu / UTC Clock
                Semantics(
                  label: 'Universal Coordinated Time Zulu: ${_formatZulu(_nowUtc)}',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colors.resultsBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.dividerStrong.withValues(alpha: 0.6),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 14, color: colors.accent),
                        const SizedBox(width: 6),
                        Text(
                          _formatZulu(_nowUtc),
                          style: uiText(
                            context,
                            size: 12,
                            weight: FontWeight.w900,
                            color: colors.textPrimary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSimPill(BuildContext context, bool isConnected, SimBridgeStatus? bridgeStatus) {
    final colors = context.colors;
    Color statusColor;
    String statusText;

    if (isConnected) {
      statusColor = colors.arrival;
      statusText = 'SIM LIVE';
    } else if (bridgeStatus == SimBridgeStatus.started || bridgeStatus == SimBridgeStatus.alreadyRunning) {
      statusColor = colors.mvfr;
      statusText = 'WAITING SIM';
    } else {
      statusColor = colors.textDim;
      statusText = 'SIM OFFLINE';
    }

    return Semantics(
      label: 'Flight Simulator Connection Status: $statusText',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: statusColor.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              statusText,
              style: uiText(
                context,
                size: 10,
                weight: FontWeight.w900,
                color: statusColor,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderPill(
    BuildContext context, {
    required String label,
    required String value,
    bool? isPopulated,
  }) {
    final colors = context.colors;
    final populated = isPopulated ?? (value.isNotEmpty && value != '--');
    const activeText = Color(0xFF101012);

    return Semantics(
      label: '$label: ${value.isEmpty || value == "--" ? "none" : value}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: populated ? colors.accent : colors.resultsBg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: populated
                ? colors.accent
                : colors.dividerStrong.withValues(alpha: 0.5),
            width: 1,
          ),
          boxShadow: populated
              ? [
                  BoxShadow(
                    color: colors.accent.withValues(alpha: 0.25),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$label: ',
              style: uiText(
                context,
                size: 9.5,
                weight: populated ? FontWeight.w800 : FontWeight.w700,
                color: populated
                    ? activeText.withValues(alpha: 0.75)
                    : colors.textDim,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              value.isEmpty ? '--' : value,
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w900,
                color: populated ? activeText : colors.textDim,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
