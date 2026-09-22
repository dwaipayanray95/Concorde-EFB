import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/efb_providers.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../../../core/app_colors.dart';
import '../../../core/ui_text.dart';
import '../../../core/concorde_logic.dart';
import '../../../services/simbrief_service.dart';
import '../../../services/flight_plan_import_service.dart';

/// FLIGHT PLAN card: three ways to load a plan -- SimBrief import, a
/// dropped .pln/route-XML file, or hand-typed route -- plus the
/// callsign/registration/passenger chips and route/distance summary row.
class FlightPlanSection extends ConsumerWidget {
  const FlightPlanSection({super.key});

  /// Applies a parsed plan to the shared providers and, when both airports
  /// resolve in the offline database, fills in a great-circle distance so
  /// the card is never left showing a stale/default figure after import.
  void _applyParsedPlan(
    WidgetRef ref,
    ParsedFlightPlan plan,
    FlightPlanSource source,
  ) {
    ref.read(departureIcaoProvider.notifier).set(plan.departureIcao);
    ref.read(arrivalIcaoProvider.notifier).set(plan.arrivalIcao);
    ref.invalidate(departureMetarFutureProvider);
    ref.invalidate(arrivalMetarFutureProvider);
    if (plan.alternateIcao != null && plan.alternateIcao!.isNotEmpty) {
      ref.read(alternateIcaoProvider.notifier).set(plan.alternateIcao!);
    }
    ref.read(simbriefRouteProvider.notifier).set(plan.route.isEmpty ? '--' : plan.route);
    ref.read(flightPlanSourceProvider.notifier).set(source);
    ref.read(checklistProvider.notifier).resetAll();

    final db = ref.read(airportDbProvider).value;
    final dep = db?.airports[plan.departureIcao];
    final arr = db?.airports[plan.arrivalIcao];

    if (plan.departureRunway != null && plan.departureRunway!.isNotEmpty) {
      final match = _findMatchingRunwayId(dep?.runways, plan.departureRunway!);
      ref.read(departureRunwayIdProvider.notifier).set(match ?? plan.departureRunway!);
    }
    if (plan.arrivalRunway != null && plan.arrivalRunway!.isNotEmpty) {
      final match = _findMatchingRunwayId(arr?.runways, plan.arrivalRunway!);
      ref.read(arrivalRunwayIdProvider.notifier).set(match ?? plan.arrivalRunway!);
    }

    if (dep != null && arr != null) {
      ref.read(plannedDistanceProvider.notifier).set(
            ConcordeLogic.greatCircleNM(dep.lat, dep.lon, arr.lat, arr.lon),
          );
    }
  }

  static String? _findMatchingRunwayId(List<dynamic>? runways, String rwyId) {
    if (runways == null || runways.isEmpty) return null;
    final target = rwyId.toUpperCase().replaceAll('RW', '').trim();
    for (final r in runways) {
      final id = (r.id as String).toUpperCase();
      if (id == target || id.padLeft(3, '0') == target.padLeft(3, '0')) {
        return r.id as String;
      }
    }
    // Also try matching without leading zeros (e.g. "05L" vs "5L")
    final strippedTarget = target.replaceFirst(RegExp(r'^0+'), '');
    for (final r in runways) {
      final id = (r.id as String).toUpperCase();
      final strippedId = id.replaceFirst(RegExp(r'^0+'), '');
      if (strippedId == strippedTarget) {
        return r.id as String;
      }
    }
    return null;
  }

  Future<void> _importFile(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    try {
      final picked = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pln', 'xml', 'fpl'],
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      final content = String.fromCharCodes(bytes);
      final plan = FlightPlanImportService.parseAnyXml(content);

      if (plan == null) {
        if (context.mounted) {
          _showSnack(context, 'Could not find a route in "${picked.name}" -- unrecognized format.', colors.error);
        }
        return;
      }

      _applyParsedPlan(ref, plan, FlightPlanSource.file);
      if (context.mounted) {
        _showSnack(context, 'Flight plan imported from ${picked.name}.', colors.success);
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, 'File import failed: $e', colors.error);
      }
    }
  }

  void _showSnack(BuildContext context, String text, Color background) {
    final colors = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: uiText(context, color: Colors.white)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: background == colors.success || background == colors.error ? background : colors.surface,
      ),
    );
  }

  Future<void> _openManualEntry(BuildContext context, WidgetRef ref) async {
    final colors = context.colors;
    final depCtl = TextEditingController(text: ref.read(departureIcaoProvider));
    final arrCtl = TextEditingController(text: ref.read(arrivalIcaoProvider));
    final altCtl = TextEditingController(text: ref.read(alternateIcaoProvider));
    final routeCtl = TextEditingController(
      text: ref.read(simbriefRouteProvider) == '--' ? '' : ref.read(simbriefRouteProvider),
    );

    final applied = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: colors.dividerStrong, width: 1.5),
        ),
        title: Text(
          'MANUAL ROUTE ENTRY',
          style: uiText(dialogContext, color: colors.textPrimary, weight: FontWeight.w900, size: 16, letterSpacing: 1.5),
        ),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: EfbTextField(
                        label: 'DEPARTURE ICAO',
                        initialValue: depCtl.text,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) => depCtl.text = v,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: EfbTextField(
                        label: 'ARRIVAL ICAO',
                        initialValue: arrCtl.text,
                        textCapitalization: TextCapitalization.characters,
                        onChanged: (v) => arrCtl.text = v,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                EfbTextField(
                  label: 'ALTERNATE ICAO (OPTIONAL)',
                  initialValue: altCtl.text,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => altCtl.text = v,
                ),
                const SizedBox(height: 14),
                Text(
                  'ROUTE (PASTE OR TYPE)',
                  style: uiText(dialogContext, color: colors.textSecondary, size: 11, weight: FontWeight.bold, letterSpacing: 0.5),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: colors.inputBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.dividerStrong, width: 1.5),
                  ),
                  child: TextField(
                    controller: routeCtl,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.characters,
                    style: uiText(dialogContext, color: colors.textPrimary, weight: FontWeight.bold, size: 14),
                    decoration: InputDecoration(
                      hintText: 'e.g. DVR KONAN UL9 KOK UN57 REMBA ...',
                      hintStyle: uiText(dialogContext, color: colors.textDim, size: 13),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text('CANCEL', style: uiText(dialogContext, color: colors.textDim, weight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              // Pre-parse the route in case the user pasted the entire route
              // (including DEP/ARR ICAOs) directly into the route field.
              final preParsed = FlightPlanImportService.parseManualRoute(
                routeCtl.text,
                defaultDep: depCtl.text,
                defaultArr: arrCtl.text,
                defaultAlt: altCtl.text,
              );
              final dep = preParsed.departureIcao.trim().toUpperCase();
              final arr = preParsed.arrivalIcao.trim().toUpperCase();
              if (dep.length != 4 || arr.length != 4) {
                _showSnack(dialogContext, 'Departure and arrival need valid 4-letter ICAO codes.', colors.error);
                return;
              }
              depCtl.text = dep;
              arrCtl.text = arr;
              Navigator.of(dialogContext).pop(true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text('APPLY', style: uiText(dialogContext, color: Colors.white, weight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (applied == true) {
      final parsed = FlightPlanImportService.parseManualRoute(
        routeCtl.text,
        defaultDep: depCtl.text,
        defaultArr: arrCtl.text,
        defaultAlt: altCtl.text,
      );
      _applyParsedPlan(ref, parsed, FlightPlanSource.manual);
      if (context.mounted) {
        _showSnack(context, 'Route applied manually.', colors.success);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final isLoading = ref.watch(simbriefLoadingProvider);
    final source = ref.watch(flightPlanSourceProvider);
    final mission = ref.watch(missionProfileProvider);

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
      right: source == FlightPlanSource.none ? null : _sourceBadge(context, source),
      child: Column(
        children: [
          // Import methods row: SimBrief (inline field + button), then two
          // compact buttons for the file and manual-entry paths.
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 2,
                child: EfbTextField(
                  label: 'SIMBRIEF USERNAME / ID (OPTIONAL)',
                  showLabel: false,
                  initialValue: ref.watch(simbriefUserProvider),
                  onChanged: (v) =>
                      ref.read(simbriefUserProvider.notifier).set(v),
                  placeholder: 'SimBrief username / ID (optional)',
                ),
              ),
              const SizedBox(width: 10),
              _ImportButton(
                icon: isLoading ? null : Icons.cloud_download_outlined,
                loading: isLoading,
                label: 'SIMBRIEF',
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
                            ref
                                .read(flightPlanSourceProvider.notifier)
                                .set(FlightPlanSource.simbrief);
                            ref.invalidate(departureMetarFutureProvider);
                            ref.invalidate(arrivalMetarFutureProvider);
                            ref.read(checklistProvider.notifier).resetAll();
                          } else if (context.mounted) {
                            _showSnack(
                              context,
                              'SimBrief import failed. Check your username/ID and internet connection.',
                              colors.error,
                            );
                          }
                        } finally {
                          ref
                              .read(simbriefLoadingProvider.notifier)
                              .set(false);
                        }
                      },
              ),
              const SizedBox(width: 8),
              _ImportButton(
                icon: Icons.upload_file_outlined,
                label: 'FILE',
                onPressed: () => _importFile(context, ref),
              ),
              const SizedBox(width: 8),
              _ImportButton(
                icon: Icons.edit_note_outlined,
                label: 'MANUAL',
                onPressed: () => _openManualEntry(context, ref),
              ),
              const SizedBox(width: 20),
              // Flight Phase Time Strip
              Expanded(
                flex: 3,
                child: _FlightPhaseStrip(
                  phases: [
                    MapEntry('TOTAL FLIGHT TIME', mission.totalTimeH),
                    MapEntry('CLIMB', mission.climb.timeH),
                    MapEntry('CRUISE', mission.cruise.timeH),
                    MapEntry('DESCENT', mission.descent.timeH),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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

  Widget _sourceBadge(BuildContext context, FlightPlanSource source) {
    final colors = context.colors;
    final label = switch (source) {
      FlightPlanSource.simbrief => 'SIMBRIEF',
      FlightPlanSource.file => 'FILE IMPORT',
      FlightPlanSource.manual => 'MANUAL',
      FlightPlanSource.none => '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        'SOURCE: $label',
        style: uiText(context, color: colors.accent, size: 9, weight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }
}

class _ImportButton extends StatelessWidget {
  final IconData? icon;
  final bool loading;
  final String label;
  final VoidCallback? onPressed;

  const _ImportButton({
    this.icon,
    this.loading = false,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: onPressed == null
            ? null
            : [
                BoxShadow(
                  color: colors.accent.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(icon, size: 15),
        label: Text(
          label,
          style: uiText(context, size: 12, weight: FontWeight.bold, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: Colors.white,
          disabledBackgroundColor: colors.accent.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final String value;
  final bool alignLeft;
  final bool isNumeric;

  const _InfoChip({
    required this.label,
    required this.value,
    this.alignLeft = false,
    this.isNumeric = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(12),
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
              color: colors.textDim,
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
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightPhaseStrip extends StatelessWidget {
  final List<MapEntry<String, double>> phases;
  const _FlightPhaseStrip({required this.phases});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colors.inputBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (var i = 0; i < phases.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 26,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: colors.dividerStrong.withValues(alpha: 0.5),
              ),
            Expanded(
              child: _PhaseTimeColumn(
                label: phases[i].key,
                hoursDecimal: phases[i].value,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PhaseTimeColumn extends StatelessWidget {
  final String label;
  final double hoursDecimal;
  const _PhaseTimeColumn({required this.label, required this.hoursDecimal});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final h = hoursDecimal.floor();
    final m = ((hoursDecimal - h) * 60).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            style: uiText(
              context,
              color: colors.textPrimary,
              weight: FontWeight.w900,
            ),
            children: [
              TextSpan(
                text: '$h',
                style: const TextStyle(fontSize: 14),
              ),
              TextSpan(
                text: 'h ',
                style: uiText(
                  context,
                  size: 9.5,
                  color: colors.textDim,
                  weight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: m.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 14),
              ),
              TextSpan(
                text: 'm',
                style: uiText(
                  context,
                  size: 9.5,
                  color: colors.textDim,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: uiText(
            context,
            size: 8.5,
            weight: FontWeight.bold,
            color: colors.textDim,
            letterSpacing: 0.5,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

