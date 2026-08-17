import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../widgets/efb_glass_container.dart';
import '../../../core/ui_tokens.dart';
import '../../../services/simbrief_service.dart';

/// FLIGHT PLAN card: SimBrief import, callsign/registration/passenger
/// chips, and the route/distance summary row.
class FlightPlanSection extends ConsumerWidget {
  const FlightPlanSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading = ref.watch(simbriefLoadingProvider);

    return EfbCard(
      title: 'FLIGHT PLAN',
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
                  onChanged: (v) => ref.read(simbriefUserProvider.notifier).set(v),
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
                      color: UiTokens.accent.withValues(alpha: 0.35),
                      blurRadius: 16,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : () async {
                    final user = ref.read(simbriefUserProvider);
                    if (user.isEmpty) return;
                    ref.read(simbriefLoadingProvider.notifier).set(true);
                    try {
                      final ofp = await SimBriefService().fetchLatestOFP(user);
                      if (ofp != null) {
                        ref.read(callSignProvider.notifier).set(ofp['general']?['atc_callsign'] ?? ofp['atc']?['callsign'] ?? '--');
                        ref.read(registrationProvider.notifier).set(ofp['aircraft']?['reg'] ?? '--');
                        ref.read(departureIcaoProvider.notifier).set(ofp['origin']?['icao_code'] ?? '');
                        ref.read(arrivalIcaoProvider.notifier).set(ofp['destination']?['icao_code'] ?? '');
                        ref.read(alternateIcaoProvider.notifier).set(ofp['alternate']?['icao_code'] ?? '');
                        ref.read(plannedDistanceProvider.notifier).set(double.tryParse(ofp['general']?['route_distance'] ?? '0') ?? 0.0);
                        ref.read(paxCountProvider.notifier).set(int.tryParse(ofp['weights']?['pax_count'] ?? '100') ?? 100);

                        ref.read(departureRunwayIdProvider.notifier).set(ofp['origin']?['plan_rwy'] ?? '');
                        ref.read(arrivalRunwayIdProvider.notifier).set(ofp['destination']?['plan_rwy'] ?? '');

                        ref.read(simbriefRouteProvider.notifier).set(ofp['general']?['route'] ?? '--');
                        ref.read(simbriefLoadedProvider.notifier).set(true);
                        ref.read(checklistProvider.notifier).resetAll();
                      } else if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'SimBrief import failed. Check your username/ID and internet connection.',
                              style: GoogleFonts.plusJakartaSans(color: Colors.white),
                            ),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: UiTokens.error.withValues(alpha: 0.9),
                          ),
                        );
                      }
                    } finally {
                      ref.read(simbriefLoadingProvider.notifier).set(false);
                    }
                  },
                  icon: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.download, size: 16),
                  label: Text(
                    'Import',
                    style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: UiTokens.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: _InfoChip(
                  label: 'CALL SIGN',
                  value: ref.watch(callSignProvider),
                  glassColor: ref.watch(simbriefLoadedProvider)
                      ? const Color(0x3310B981) // Solid glass green (Emerald)
                      : null,
                  boxShadow: ref.watch(simbriefLoadedProvider)
                      ? [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InfoChip(
                  label: 'REGISTRATION',
                  value: ref.watch(registrationProvider),
                  glassColor: ref.watch(simbriefLoadedProvider)
                      ? const Color(0x33F59E0B) // Solid glass yellow (Amber)
                      : null,
                  boxShadow: ref.watch(simbriefLoadedProvider)
                      ? [
                          BoxShadow(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                            blurRadius: 20,
                            spreadRadius: 2,
                          )
                        ]
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(child: _InfoChip(label: 'PASSENGERS', value: '${ref.watch(paxCountProvider)}', isNumeric: true)),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: EfbGlassContainer(
                  blur: 10,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    width: double.infinity,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${ref.watch(departureIcaoProvider)} → ${ref.watch(arrivalIcaoProvider)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: UiTokens.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'ALT: ${ref.watch(alternateIcaoProvider)}',
                          style: GoogleFonts.jetBrainsMono(
                            color: UiTokens.textDim,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 3,
                child: InkWell(
                  onTap: () {
                    final route = ref.read(simbriefRouteProvider);
                    if (route.isNotEmpty && route != '--') {
                      Clipboard.setData(ClipboardData(text: route));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Route copied to clipboard!',
                            style: GoogleFonts.plusJakartaSans(color: Colors.white),
                          ),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: UiTokens.surface,
                        ),
                      );

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          backgroundColor: UiTokens.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          title: Text(
                            'FULL ROUTE',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                          content: SingleChildScrollView(
                            child: SelectableText(
                              route,
                              style: GoogleFonts.jetBrainsMono(
                                color: UiTokens.textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: Text(
                                'CLOSE',
                                style: GoogleFonts.plusJakartaSans(
                                  color: UiTokens.textDim,
                                  fontWeight: FontWeight.bold,
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
                  child: EfbGlassContainer(
                    blur: 10,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      width: double.infinity,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          const Icon(Icons.route, color: UiTokens.textDim, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              ref.watch(simbriefRouteProvider),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.jetBrainsMono(
                                color: ref.watch(simbriefRouteProvider) == '--'
                                    ? UiTokens.textDim
                                    : UiTokens.textSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.copy_all,
                            color: ref.watch(simbriefRouteProvider) == '--'
                                ? UiTokens.textDim.withValues(alpha: 0.5)
                                : UiTokens.accent,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: _InfoChip(label: 'ROUTE DISTANCE', value: '${ref.watch(plannedDistanceProvider).round()} NM', alignLeft: true, isNumeric: true),
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
  final Color? glassColor;
  final List<BoxShadow>? boxShadow;

  const _InfoChip({
    required this.label,
    required this.value,
    this.alignLeft = false,
    this.isNumeric = false,
    this.glassColor,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return EfbGlassContainer(
      blur: 10,
      borderRadius: BorderRadius.circular(12),
      color: glassColor,
      boxShadow: boxShadow,
      child: Container(
        height: 48,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: alignLeft ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: glassColor != null ? Colors.white.withValues(alpha: 0.6) : UiTokens.textDim,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: (isNumeric ? GoogleFonts.jetBrainsMono : GoogleFonts.plusJakartaSans)(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: glassColor != null ? Colors.white : UiTokens.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
