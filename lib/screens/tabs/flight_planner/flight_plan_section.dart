import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../services/simbrief_service.dart';

/// FLIGHT PLAN card: SimBrief import, callsign/registration/passenger
/// chips, and the route/distance summary row.
class FlightPlanSection extends ConsumerWidget {
  const FlightPlanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isLoading = ref.watch(simbriefLoadingProvider);
    final isLoaded = ref.watch(simbriefLoadedProvider);

    // VATSIM-chart-style route: DEP/RWY ...enroute... ARR/RWY, so it can be
    // pasted straight into the MSFS world map flight planner.
    final rawRoute = ref.watch(simbriefRouteProvider);
    final depIcao = ref.watch(departureIcaoProvider);
    final arrIcao = ref.watch(arrivalIcaoProvider);
    final depRwy = ref.watch(departureRunwayIdProvider);
    final arrRwy = ref.watch(arrivalRunwayIdProvider);
    final hasRoute = rawRoute.isNotEmpty && rawRoute != '--';
    final dep = depIcao.isEmpty
        ? ''
        : (depRwy.isEmpty ? depIcao : '$depIcao/$depRwy');
    final arr = arrIcao.isEmpty
        ? ''
        : (arrRwy.isEmpty ? arrIcao : '$arrIcao/$arrRwy');
    final msfsRoute = [
      if (dep.isNotEmpty) dep,
      if (hasRoute) rawRoute,
      if (arr.isNotEmpty) arr,
    ].join(' ');

    return EfbCard(
      title: 'FLIGHT PLAN',
      icon: Icons.map_outlined,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: EfbTextField(
                  label: 'SIMBRIEF USERNAME / ID (OPTIONAL)',
                  initialValue: ref.watch(simbriefUserProvider),
                  onChanged: (v) =>
                      ref.read(simbriefUserProvider.notifier).set(v),
                  placeholder: 'SimBrief username',
                ),
              ),
              const SizedBox(width: 16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: isLoading
                      ? null
                      : () async {
                          final user = ref.read(simbriefUserProvider);
                          if (user.isEmpty) return;
                          ref.read(simbriefLoadingProvider.notifier).set(true);
                          try {
                            final ofp = await SimBriefService().fetchLatestOFP(
                              user,
                            );
                            if (ofp != null) {
                              ref
                                  .read(callSignProvider.notifier)
                                  .set(
                                    ofp['general']?['atc_callsign'] ??
                                        ofp['atc']?['callsign'] ??
                                        '--',
                                  );
                              ref
                                  .read(registrationProvider.notifier)
                                  .set(ofp['aircraft']?['reg'] ?? '--');
                              ref
                                  .read(departureIcaoProvider.notifier)
                                  .set(ofp['origin']?['icao_code'] ?? '');
                              ref
                                  .read(arrivalIcaoProvider.notifier)
                                  .set(ofp['destination']?['icao_code'] ?? '');
                              ref
                                  .read(alternateIcaoProvider.notifier)
                                  .set(ofp['alternate']?['icao_code'] ?? '');
                              ref
                                  .read(plannedDistanceProvider.notifier)
                                  .set(
                                    double.tryParse(
                                          ofp['general']?['route_distance'] ??
                                              '0',
                                        ) ??
                                        0.0,
                                  );
                              ref
                                  .read(paxCountProvider.notifier)
                                  .set(
                                    int.tryParse(
                                          ofp['weights']?['pax_count'] ?? '100',
                                        ) ??
                                        100,
                                  );

                              ref
                                  .read(departureRunwayIdProvider.notifier)
                                  .set(ofp['origin']?['plan_rwy'] ?? '');
                              ref
                                  .read(arrivalRunwayIdProvider.notifier)
                                  .set(ofp['destination']?['plan_rwy'] ?? '');

                              ref
                                  .read(simbriefRouteProvider.notifier)
                                  .set(ofp['general']?['route'] ?? '--');
                              ref
                                  .read(simbriefLoadedProvider.notifier)
                                  .set(true);
                              ref.read(checklistProvider.notifier).resetAll();
                            } else if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'SimBrief import failed. Check your username/ID and internet connection.',
                                    style: uiText(context, color: Colors.white),
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: colors.error,
                                ),
                              );
                            }
                          } finally {
                            ref
                                .read(simbriefLoadingProvider.notifier)
                                .set(false);
                          }
                        },
                  icon: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download, size: 16),
                  label: Text(
                    'Import',
                    style: uiText(
                      context,
                      size: 14,
                      weight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _InfoChip(
                  label: 'CALL SIGN',
                  value: ref.watch(callSignProvider),
                  backgroundColor: isLoaded ? colors.success : null,
                  textColor: isLoaded ? Colors.white : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoChip(
                  label: 'REGISTRATION',
                  value: ref.watch(registrationProvider),
                  backgroundColor: isLoaded ? const Color(0xFFFF9800) : null,
                  textColor: isLoaded ? Colors.white : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoChip(
                  label: 'PASSENGERS',
                  value: '${ref.watch(paxCountProvider)}',
                  isNumeric: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(
                  height: 48,
                  width: double.infinity,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: colors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.dividerStrong, width: 1.5),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${ref.watch(departureIcaoProvider)} → ${ref.watch(arrivalIcaoProvider)}',
                        style: uiText(
                          context,
                          color: colors.textPrimary,
                          size: 13,
                          weight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'ALT: ${ref.watch(alternateIcaoProvider)}',
                        style: uiText(
                          context,
                          color: colors.textDim,
                          size: 10,
                          weight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    if (msfsRoute.isNotEmpty) {
                      Clipboard.setData(ClipboardData(text: msfsRoute));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Route copied to clipboard!',
                            style: uiText(context, color: Colors.white),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: colors.surface,
                        ),
                      );

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: colors.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: colors.dividerStrong,
                              width: 1.5,
                            ),
                          ),
                          title: Text(
                            'FULL ROUTE',
                            style: uiText(
                              context,
                              color: colors.textPrimary,
                              weight: FontWeight.w900,
                              size: 16,
                              letterSpacing: 1.5,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: SelectableText(
                              msfsRoute,
                              style: uiText(
                                context,
                                color: colors.textSecondary,
                                size: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton.icon(
                              onPressed: () {
                                Clipboard.setData(
                                  ClipboardData(text: msfsRoute),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Route copied to clipboard!',
                                      style: uiText(
                                        context,
                                        color: Colors.white,
                                      ),
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: colors.surface,
                                  ),
                                );
                              },
                              icon: Icon(
                                Icons.copy_all,
                                size: 16,
                                color: colors.accent,
                              ),
                              label: Text(
                                'COPY',
                                style: uiText(
                                  context,
                                  color: colors.accent,
                                  weight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'CLOSE',
                                style: uiText(
                                  context,
                                  color: colors.textDim,
                                  weight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  mouseCursor: SystemMouseCursors.click,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: colors.inputBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.dividerStrong,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.route, color: colors.textDim, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            msfsRoute.isEmpty ? '--' : msfsRoute,
                            overflow: TextOverflow.ellipsis,
                            style: uiText(
                              context,
                              color: msfsRoute.isEmpty
                                  ? colors.textDim
                                  : colors.textPrimary,
                              size: 13,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.copy_all,
                          color: msfsRoute.isEmpty
                              ? colors.textDim.withValues(alpha: 0.5)
                              : colors.accent,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _InfoChip(
                  label: 'ROUTE DISTANCE',
                  value: '${ref.watch(plannedDistanceProvider).round()} NM',
                  alignLeft: true,
                  isNumeric: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool alignLeft;
  final bool isNumeric;
  final Color? backgroundColor;
  final Color? textColor;

  const _InfoChip({
    required this.label,
    required this.value,
    this.alignLeft = false,
    this.isNumeric = false,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final isColored = backgroundColor != null;
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: backgroundColor ?? colors.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: isColored
            ? null
            : Border.all(color: colors.dividerStrong, width: 1.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: alignLeft
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.bold,
              color: textColor != null
                  ? textColor!.withValues(alpha: 0.85)
                  : colors.textDim,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: uiText(
              context,
              size: 14,
              weight: FontWeight.bold,
              color: textColor ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
