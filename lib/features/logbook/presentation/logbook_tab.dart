import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/app_colors.dart';
import '../../../core/formatters.dart';
import '../../../core/ui_text.dart';
import '../../../widgets/efb_card.dart';
import '../../../widgets/efb_flat_card.dart';
import '../../../widgets/efb_text_field.dart';
import '../data/flight_log.dart';
import '../data/logbook_repository.dart';
import '../data/logbook_sync.dart';
import '../domain/landing_rating.dart';
import '../../flight_monitor/data/services/lan_link.dart';
import 'logbook_format.dart';
import 'logbook_providers.dart';
import 'widgets/flight_sparkline.dart';
import 'widgets/flight_profile_chart.dart';
import 'widgets/cg_corridor_chart.dart';
import 'widgets/runway_performance_card.dart';
import 'widgets/acars_fuel_release.dart';

bool get _isRemoteClient => isRemoteClientPlatform;
bool get _isPhone => isMobilePlatform;

String _route(FlightLog l) {
  final dep = l.actualDep ?? l.plannedDep;
  final arr = l.actualArr ?? l.plannedArr;
  return '${dep.isEmpty ? '----' : dep} → ${arr.isEmpty ? '----' : arr}';
}

enum _FilterMode { all, supersonic, butterSmooth, firm }

/// LOG tab: Pilot career dossier, butter landing distribution, search/filters,
/// and avionics flight cards with embedded vector profile sparklines.
class LogbookTab extends ConsumerStatefulWidget {
  const LogbookTab({super.key});

  @override
  ConsumerState<LogbookTab> createState() => _LogbookTabState();
}

class _LogbookTabState extends ConsumerState<LogbookTab> {
  String _searchQuery = '';
  _FilterMode _filterMode = _FilterMode.all;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final async = ref.watch(logbookProvider);
    final allLogs = [...?async.value]
      ..sort((a, b) => b.blockOut.compareTo(a.blockOut));

    // Filter by search query & category
    final filteredLogs = allLogs.where((l) {
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final dep = (l.actualDep ?? l.plannedDep).toLowerCase();
        final arr = (l.actualArr ?? l.plannedArr).toLowerCase();
        final cs = l.callSign.toLowerCase();
        final reg = l.registration.toLowerCase();
        final notes = l.notes.toLowerCase();
        if (!dep.contains(q) &&
            !arr.contains(q) &&
            !cs.contains(q) &&
            !reg.contains(q) &&
            !notes.contains(q)) {
          return false;
        }
      }
      switch (_filterMode) {
        case _FilterMode.all:
          return true;
        case _FilterMode.supersonic:
          return l.maxMach >= 1.0 || l.supersonicSec > 0;
        case _FilterMode.butterSmooth:
          final r = l.landingRating;
          return r == LandingRating.butter || r == LandingRating.smooth;
        case _FilterMode.firm:
          return l.landingRating == LandingRating.firm;
      }
    }).toList();

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (_isRemoteClient) ...[const _SyncLine(), const SizedBox(height: 8)],
        _CareerDossier(logs: allLogs),
        const SizedBox(height: 12),
        _LogbookToolbar(
          logs: allLogs,
          filteredCount: filteredLogs.length,
          searchCtrl: _searchCtrl,
          activeFilter: _filterMode,
          onSearchChanged: (v) => setState(() => _searchQuery = v.trim()),
          onFilterChanged: (m) => setState(() => _filterMode = m),
        ),
        const SizedBox(height: 12),
        if (async.isLoading && allLogs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (allLogs.isEmpty)
          EfbFlatCard(
            padding: const EdgeInsets.all(28),
            child: Text(
              _isRemoteClient
                  ? 'Flights are logged by the Concorde EFB app on your sim PC and '
                        'appear here when this device connects to it.'
                  : 'No flights logged yet. Flights are recorded '
                        'automatically while the Flight Monitor is connected.',
              textAlign: TextAlign.center,
              style: uiText(context, size: 13, color: colors.textSecondary),
            ),
          )
        else if (filteredLogs.isEmpty)
          EfbFlatCard(
            padding: const EdgeInsets.all(24),
            child: Text(
              'No flights match the current search / filter criteria.',
              textAlign: TextAlign.center,
              style: uiText(context, size: 12, color: colors.textSecondary),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < filteredLogs.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _AvionicsFlightCard(log: filteredLogs[i]),
              ],
            ],
          ),
      ],
    );
  }
}

/// Phone only: whether the list mirrors the desktop right now.
class _SyncLine extends ConsumerWidget {
  const _SyncLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(logbookSyncProvider);
    final host = ref.watch(remoteBridgeProvider).host;
    final t = sync.lastSync?.toLocal();
    final time = t == null
        ? ''
        : '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return Text(
      sync.connected && t != null
          ? 'Synced with $host · $time'
          : sync.connected
          ? 'Syncing with $host…'
          : 'Not connected to the sim PC — showing last synced copy',
      style: uiText(context, size: 11, color: context.colors.textSecondary),
    );
  }
}

/// Flight Deck Career Dossier: comprehensive pilot stats, supersonic ratio gauge,
/// and butter landing distribution histogram.
class _CareerDossier extends StatelessWidget {
  final List<FlightLog> logs;
  const _CareerDossier({required this.logs});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var totalBlock = Duration.zero;
    var totalSupersonicSec = 0.0;
    var totalDistanceNm = 0.0;
    var maxMachAll = 0.0;

    for (final l in logs) {
      totalBlock += l.blockTime ?? Duration.zero;
      totalSupersonicSec += l.supersonicSec;
      totalDistanceNm += l.distanceNm;
      if (l.maxMach > maxMachAll) maxMachAll = l.maxMach;
    }

    final landed = logs
        .where((l) => l.touchdown != null && l.touchdownFpm != null)
        .toList();

    FlightLog? bestTouchdown;
    for (final l in landed) {
      if (bestTouchdown == null ||
          l.touchdownFpm!.abs() < bestTouchdown.touchdownFpm!.abs()) {
        bestTouchdown = l;
      }
    }

    final avgLandingFpm = landed.isEmpty
        ? null
        : landed.fold<double>(0, (s, l) => s + l.touchdownFpm!.abs()) /
              landed.length;

    final totalBlockSec = totalBlock.inSeconds;
    final ssRatio = totalBlockSec > 0
        ? (totalSupersonicSec / totalBlockSec).clamp(0.0, 1.0)
        : 0.0;

    // Butter distribution counts
    final butter = landed
        .where((l) => l.landingRating == LandingRating.butter)
        .length;
    final smooth = landed
        .where((l) => l.landingRating == LandingRating.smooth)
        .length;
    final firm = landed.where((l) => l.landingRating == LandingRating.firm).length;
    final hard = landed.where((l) => l.landingRating == LandingRating.hard).length;
    final insp = landed
        .where((l) => l.landingRating == LandingRating.inspection)
        .length;

    final avgBlock = logs.isEmpty
        ? Duration.zero
        : Duration(seconds: totalBlockSec ~/ logs.length);

    return EfbFlatCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Bar
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: colors.accent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accent.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'FLIGHT DECK CAREER DOSSIER',
                style: uiText(
                  context,
                  size: 11,
                  weight: FontWeight.w900,
                  color: colors.accent,
                  letterSpacing: 1.2,
                ),
              ),
              const Spacer(),
              Text(
                'DC DESIGNS CONCORDE',
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w700,
                  color: colors.textDim,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(
            height: 1,
            color: colors.dividerStrong.withValues(alpha: 0.4),
          ),
          const SizedBox(height: 12),

          // 6 KPI Metric Cards
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final mid = c.maxWidth >= 480;

              Widget tile(
                String label,
                String val,
                String sub, {
                Color? valColor,
                Color? subColor,
              }) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: colors.resultsBg,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: colors.dividerStrong.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiText(
                        context,
                        size: 9,
                        weight: FontWeight.w800,
                        color: colors.textDim,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        val,
                        style: uiText(
                          context,
                          size: 16,
                          weight: FontWeight.w900,
                          color: valColor ?? colors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: uiText(
                        context,
                        size: 9,
                        weight: FontWeight.w700,
                        color: subColor ?? colors.textDim,
                      ),
                    ),
                  ],
                ),
              );

              final tiles = [
                tile(
                  'FLIGHTS',
                  '${logs.length}',
                  '100% DISPATCH',
                  subColor: colors.success,
                ),
                tile(
                  'BLOCK HOURS',
                  hm(totalBlock),
                  'AVG ${hm(avgBlock)} / FLT',
                ),
                tile(
                  'SUPERSONIC',
                  hm(Duration(seconds: totalSupersonicSec.round())),
                  '${(ssRatio * 100).round()}% OF CRUISE',
                  valColor: colors.accent,
                  subColor: colors.accent,
                ),
                tile(
                  'AVG LANDING',
                  avgLandingFpm == null
                      ? '--'
                      : '${avgLandingFpm.round()} FPM',
                  avgLandingFpm != null ? 'RATE OF DESCENT' : 'NIL',
                  valColor: colors.success,
                ),
                tile(
                  'BEST LANDING',
                  bestTouchdown == null
                      ? '--'
                      : '${bestTouchdown.touchdownFpm!.abs().round()} FPM',
                  bestTouchdown != null
                      ? '${bestTouchdown.touchdownG?.toStringAsFixed(2) ?? '1.0'} G · ${dateText(bestTouchdown.blockOut)}'
                      : 'NIL',
                  valColor: colors.success,
                  subColor: colors.success,
                ),
                tile(
                  'DISTANCE FLOWN',
                  '${numFormat.format(totalDistanceNm.round())} NM',
                  '${(totalDistanceNm / 21600).toStringAsFixed(1)}× GLOBE',
                ),
              ];

              if (wide) {
                return Row(
                  children: [
                    for (var i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              } else if (mid) {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[1]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[2]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: tiles[3]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[4]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[5]),
                      ],
                    ),
                  ],
                );
              } else {
                return Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[1]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[3]),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: tiles[4]),
                        const SizedBox(width: 8),
                        Expanded(child: tiles[5]),
                      ],
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Two Visual Telemetry Progress Bars
          LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final supersonicBar = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SUPERSONIC FLIGHT RATIO',
                        style: uiText(
                          context,
                          size: 9,
                          weight: FontWeight.w800,
                          color: colors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        '${hm(Duration(seconds: totalSupersonicSec.round()))} / ${hm(totalBlock)} (${(ssRatio * 100).round()}%)',
                        style: uiText(
                          context,
                          size: 9,
                          weight: FontWeight.w900,
                          color: colors.accent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 7,
                      color: colors.resultsBg,
                      child: Row(
                        children: [
                          if (ssRatio > 0)
                            Expanded(
                              flex: (ssRatio * 100).round(),
                              child: Container(color: colors.accent),
                            ),
                          if (ssRatio < 1.0)
                            Expanded(
                              flex: (100 - ssRatio * 100).round(),
                              child: Container(
                                color: colors.dividerStrong.withValues(alpha: 0.6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'SUBSONIC (${(100 - ssRatio * 100).clamp(0, 100).round()}%)',
                        style: uiText(context, size: 8, color: colors.textDim),
                      ),
                      Text(
                        'MACH 2.0+ SUPERCRUISE (${(ssRatio * 100).clamp(0, 100).round()}%)',
                        style: uiText(context, size: 8, color: colors.accent),
                      ),
                    ],
                  ),
                ],
              );

              final butterBar = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'LANDING BUTTER DISTRIBUTION (${landed.length} FLIGHTS)',
                        style: uiText(
                          context,
                          size: 9,
                          weight: FontWeight.w800,
                          color: colors.textSecondary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      Text(
                        'AVG ${avgLandingFpm != null ? fpmText(avgLandingFpm) : '--'}',
                        style: uiText(
                          context,
                          size: 9,
                          weight: FontWeight.w900,
                          color: colors.success,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 7,
                      color: colors.resultsBg,
                      child: landed.isEmpty
                          ? Container(
                              color: colors.dividerStrong.withValues(alpha: 0.4),
                            )
                          : Row(
                              children: [
                                if (butter > 0)
                                  Expanded(
                                    flex: butter,
                                    child: Container(color: colors.success),
                                  ),
                                if (smooth > 0)
                                  Expanded(
                                    flex: smooth,
                                    child: Container(
                                      color: const Color(0xFF059669),
                                    ),
                                  ),
                                if (firm > 0)
                                  Expanded(
                                    flex: firm,
                                    child: Container(color: colors.accent),
                                  ),
                                if (hard > 0)
                                  Expanded(
                                    flex: hard,
                                    child: Container(
                                      color: const Color(0xFFEA580C),
                                    ),
                                  ),
                                if (insp > 0)
                                  Expanded(
                                    flex: insp,
                                    child: Container(color: colors.error),
                                  ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      children: [
                        Text(
                          '● BUTTER: $butter  ',
                          style: uiText(
                            context,
                            size: 8,
                            weight: FontWeight.bold,
                            color: colors.success,
                          ),
                        ),
                        Text(
                          '● SMOOTH: $smooth  ',
                          style: uiText(
                            context,
                            size: 8,
                            weight: FontWeight.bold,
                            color: const Color(0xFF059669),
                          ),
                        ),
                        Text(
                          '● FIRM: $firm  ',
                          style: uiText(
                            context,
                            size: 8,
                            weight: FontWeight.bold,
                            color: colors.accent,
                          ),
                        ),
                        Text(
                          '● HARD: $hard  ',
                          style: uiText(
                            context,
                            size: 8,
                            weight: FontWeight.bold,
                            color: const Color(0xFFEA580C),
                          ),
                        ),
                        Text(
                          '● INSPECT: $insp',
                          style: uiText(
                            context,
                            size: 8,
                            weight: FontWeight.bold,
                            color: colors.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );

              if (wide) {
                return Row(
                  children: [
                    Expanded(child: supersonicBar),
                    const SizedBox(width: 24),
                    Expanded(child: butterBar),
                  ],
                );
              } else {
                return Column(
                  children: [
                    supersonicBar,
                    const SizedBox(height: 12),
                    butterBar,
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Toolbar with interactive Search, Filter pills, and Export options.
class _LogbookToolbar extends StatelessWidget {
  final List<FlightLog> logs;
  final int filteredCount;
  final TextEditingController searchCtrl;
  final _FilterMode activeFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<_FilterMode> onFilterChanged;

  const _LogbookToolbar({
    required this.logs,
    required this.filteredCount,
    required this.searchCtrl,
    required this.activeFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
  });

  Future<void> _export(BuildContext context, String ext, String content) =>
      _exportText(context, ext, content);

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final empty = logs.isEmpty;

    final ssCount = logs.where((l) => l.maxMach >= 1.0 || l.supersonicSec > 0).length;
    final butterCount = logs
        .where(
          (l) =>
              l.landingRating == LandingRating.butter ||
              l.landingRating == LandingRating.smooth,
        )
        .length;
    final firmCount =
        logs.where((l) => l.landingRating == LandingRating.firm).length;

    Widget chip(String label, _FilterMode mode) {
      final selected = activeFilter == mode;
      return Material(
        color: selected ? colors.accent : colors.resultsBg,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () => onFilterChanged(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: selected
                    ? colors.accent
                    : colors.dividerStrong.withValues(alpha: 0.6),
              ),
            ),
            child: Text(
              label,
              style: uiText(
                context,
                size: 9,
                weight: FontWeight.w900,
                color: selected ? AppColors.dark.bg : colors.textSecondary,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 720;
        final searchField = Container(
          height: 36,
          decoration: BoxDecoration(
            color: colors.resultsBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.6),
            ),
          ),
          child: TextField(
            controller: searchCtrl,
            onChanged: onSearchChanged,
            style: uiText(context, size: 11, color: colors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 9,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(Icons.search, size: 16, color: colors.textDim),
              hintText: 'Search ICAO, callsign (e.g. EGLL, BAW001)...',
              hintStyle: uiText(context, size: 11, color: colors.textDim),
              suffixIcon: searchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, size: 14, color: colors.textDim),
                      onPressed: () {
                        searchCtrl.clear();
                        onSearchChanged('');
                      },
                    )
                  : null,
            ),
          ),
        );

        final filterRow = SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              chip('ALL (${logs.length})', _FilterMode.all),
              const SizedBox(width: 6),
              chip('SUPERSONIC ($ssCount)', _FilterMode.supersonic),
              const SizedBox(width: 6),
              chip('BUTTER / SMOOTH ($butterCount)', _FilterMode.butterSmooth),
              const SizedBox(width: 6),
              chip('FIRM ($firmCount)', _FilterMode.firm),
            ],
          ),
        );

        final exportButtons = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToolButton(
              icon: Icons.table_chart_outlined,
              label: 'EXPORT CSV',
              onTap: empty
                  ? null
                  : () => _export(
                        context,
                        'csv',
                        LogbookRepository.exportCsv(logs),
                      ),
            ),
            const SizedBox(width: 8),
            _ToolButton(
              icon: Icons.data_object,
              label: 'EXPORT JSON',
              onTap: empty
                  ? null
                  : () => _export(
                        context,
                        'json',
                        LogbookRepository.exportJson(logs),
                      ),
            ),
          ],
        );

        if (wide) {
          return Row(
            children: [
              Expanded(child: searchField),
              const SizedBox(width: 10),
              filterRow,
              const SizedBox(width: 10),
              exportButtons,
            ],
          );
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: filterRow),
                  const SizedBox(width: 8),
                  exportButtons,
                ],
              ),
            ],
          );
        }
      },
    );
  }
}

class _ToolButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _ToolButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final fg = onTap == null ? colors.textDim : colors.accent;
    return Material(
      color: colors.resultsBg,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.6),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: uiText(
                  context,
                  size: 9,
                  weight: FontWeight.w900,
                  color: fg,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Upgraded Avionics Flight Tile: prominent callsign, route badge, embedded vector
/// sparkline altitude profile, flight time, cruise Mach, and high-contrast landing pill.
class _AvionicsFlightCard extends StatelessWidget {
  final FlightLog log;
  const _AvionicsFlightCard({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rating = log.landingRating;

    final isSupersonic = log.maxMach >= 1.0 || log.supersonicSec > 0;
    final toRunway = log.takeoffPerf?['plan']?['runway'] as String?;
    final ldgRunway = log.landingPerf?['plan']?['runway'] as String?;
    final runways = (toRunway != null && ldgRunway != null)
        ? ' · RWY $toRunway → $ldgRunway'
        : '';

    Widget statusPill() {
      if (log.blockIn == null || rating == null) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: colors.resultsBg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.7),
            ),
          ),
          child: Text(
            'IN PROGRESS',
            style: uiText(
              context,
              size: 10,
              weight: FontWeight.w900,
              color: colors.accent,
              letterSpacing: 0.8,
            ),
          ),
        );
      }

      final pillColor = ratingColor(colors, rating);
      final onColor = onRatingColor(colors, rating);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: pillColor.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: pillColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              fpmText(log.touchdownFpm!),
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w900,
                color: pillColor,
              ),
            ),
            Text(
              '${rating.label}${log.touchdownG != null ? ' · ${log.touchdownG!.toStringAsFixed(2)}G' : ''}',
              style: uiText(
                context,
                size: 8,
                weight: FontWeight.w800,
                color: onColor == Colors.white ? pillColor : onColor,
              ),
            ),
          ],
        ),
      );
    }

    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => LogDetailScreen(logId: log.id)),
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.5),
            ),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 720;
              final mid = c.maxWidth >= 480;

              return Row(
                children: [
                  // Callsign Block
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: colors.resultsBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: colors.dividerStrong.withValues(alpha: 0.6),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      log.callSign.isEmpty ? 'FLT' : log.callSign,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      style: uiText(
                        context,
                        size: 10,
                        weight: FontWeight.w900,
                        color: colors.accent,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Route & Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                _route(log),
                                overflow: TextOverflow.ellipsis,
                                style: uiText(
                                  context,
                                  size: 13,
                                  weight: FontWeight.w900,
                                  color: colors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            if (isSupersonic) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.accent.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: colors.accent.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  'SUPERSONIC',
                                  style: uiText(
                                    context,
                                    size: 8,
                                    weight: FontWeight.w900,
                                    color: colors.accent,
                                  ),
                                ),
                              ),
                            ],
                            if (log.goArounds > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.ifrBg,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: colors.ifr.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${log.goArounds} GO-AROUND${log.goArounds > 1 ? 'S' : ''}',
                                  style: uiText(
                                    context,
                                    size: 8,
                                    weight: FontWeight.w900,
                                    color: colors.ifr,
                                  ),
                                ),
                              ),
                            ],
                            if (log.bounces > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                decoration: BoxDecoration(
                                  color: colors.errorBg,
                                  borderRadius: BorderRadius.circular(3),
                                  border: Border.all(
                                    color: colors.error.withValues(alpha: 0.4),
                                  ),
                                ),
                                child: Text(
                                  '${log.bounces} BOUNCE${log.bounces > 1 ? 'S' : ''}',
                                  style: uiText(
                                    context,
                                    size: 8,
                                    weight: FontWeight.w900,
                                    color: colors.error,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${dateText(log.blockOut)} · REG: ${log.registration.isEmpty ? '--' : log.registration}$runways',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: uiText(
                            context,
                            size: 10,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Vector Sparkline Altitude Profile (Wide / Mid viewports)
                  if (wide || mid) ...[
                    const SizedBox(width: 12),
                    FlightSparkline(
                      track: log.track,
                      width: wide ? 130 : 90,
                      height: 32,
                      maxAltFt: log.maxAltFt,
                    ),
                  ],

                  const SizedBox(width: 14),

                  // Duration & Max Cruise Readout
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${hm(log.blockTime)} · ${numFormat.format(log.distanceNm.round())} NM',
                        style: uiText(
                          context,
                          size: 11,
                          weight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (log.maxMach > 0) ...[
                            Text(
                              'M${log.maxMach.toStringAsFixed(2)}',
                              style: uiText(
                                context,
                                size: 10,
                                weight: FontWeight.w900,
                                color: colors.accent,
                              ),
                            ),
                            Text(
                              ' · ',
                              style: uiText(
                                context,
                                size: 10,
                                color: colors.textDim,
                              ),
                            ),
                          ],
                          Text(
                            log.maxAltFt > 0
                                ? 'FL${(log.maxAltFt / 100).round()}'
                                : '--',
                            style: uiText(
                              context,
                              size: 10,
                              color: colors.textDim,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(width: 12),
                  statusPill(),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: colors.textDim),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Desktop: save dialog. Phone: copy to clipboard.
Future<void> _exportText(
  BuildContext context,
  String ext,
  String content, {
  String fileName = 'concorde-efb-logbook',
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    if (_isPhone) {
      await Clipboard.setData(ClipboardData(text: content));
      messenger?.showSnackBar(
        const SnackBar(content: Text('Copied to clipboard')),
      );
      return;
    }
    final saved = await FilePicker.saveFile(
      fileName: '$fileName.$ext',
      bytes: Uint8List.fromList(utf8.encode(content)),
      dialogTitle: 'Export logbook',
      type: FileType.custom,
      allowedExtensions: [ext],
    );
    if (saved != null) {
      messenger?.showSnackBar(
        SnackBar(content: Text('Exported (${ext.toUpperCase()})')),
      );
    }
  } catch (e) {
    messenger?.showSnackBar(SnackBar(content: Text('Export failed: $e')));
  }
}

/// Full-screen detail for one flight (pushed route).
class LogDetailScreen extends ConsumerStatefulWidget {
  final String logId;
  const LogDetailScreen({super.key, required this.logId});

  @override
  ConsumerState<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends ConsumerState<LogDetailScreen> {
  Timer? _debounce;
  String? _pendingNotes;
  late final LogbookNotifier _notifier = ref.read(logbookProvider.notifier);

  void _onNotes(String v) {
    _pendingNotes = v;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _flush);
  }

  void _flush() {
    _debounce?.cancel();
    final n = _pendingNotes;
    if (n == null) return;
    _pendingNotes = null;
    unawaited(_notifier.setNotes(widget.logId, n));
  }

  @override
  void dispose() {
    _flush();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    final colors = context.colors;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colors.surface,
        title: Text(
          'DELETE THIS FLIGHT?',
          style: uiText(
            ctx,
            size: 14,
            weight: FontWeight.w900,
            color: colors.textPrimary,
          ),
        ),
        content: Text(
          'The log entry is removed permanently.',
          style: uiText(ctx, size: 12, color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'CANCEL',
              style: uiText(ctx, weight: FontWeight.bold, color: colors.accent),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              'DELETE',
              style: uiText(ctx, weight: FontWeight.bold, color: colors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    _pendingNotes = null;
    _debounce?.cancel();
    await _notifier.delete(widget.logId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final log = ref
        .watch(logbookProvider)
        .value
        ?.where((l) => l.id == widget.logId)
        .firstOrNull;
    if (log == null) {
      return Scaffold(backgroundColor: colors.bg, body: const SizedBox());
    }
    final title =
        '${log.callSign.isEmpty ? 'FLIGHT' : log.callSign} · '
        '${_route(log)}';

    return Scaffold(
      backgroundColor: colors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: uiText(
                        context,
                        size: 16,
                        weight: FontWeight.w900,
                        color: colors.textPrimary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  Text(
                    dateText(log.blockOut),
                    style: uiText(
                      context,
                      size: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 850;

                  final notes = EfbCard(
                    title: 'PILOT DEBRIEF & NOTES',
                    child: EfbTextField(
                      label: 'Notes',
                      showLabel: false,
                      placeholder: 'Enter debrief, VATSIM ATC remarks, or flight notes...',
                      initialValue: log.notes,
                      keyboardType: TextInputType.multiline,
                      onChanged: _onNotes,
                    ),
                  );

                  final delete = Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ToolButton(
                        icon: Icons.data_object,
                        label: 'EXPORT FLIGHT DATA (JSON)',
                        onTap: () => _exportText(
                          context,
                          'json',
                          LogbookRepository.exportJson([log]),
                          fileName: 'concorde-efb-${log.id}',
                        ),
                      ),
                      _ToolButton(
                        icon: Icons.delete_outline,
                        label: 'DELETE FLIGHT',
                        onTap: _confirmDelete,
                      ),
                    ],
                  );

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    children: [
                      // 1. Hero Mission Summary & OOOI Header
                      _heroHeader(context, log),
                      const SizedBox(height: 12),

                      // 2. Interactive Dual-Axis Flight Profile Canvas
                      FlightProfileChart(log: log),
                      const SizedBox(height: 12),

                      // 3. Secondary Telemetry Grid: CG Corridor & Runway Rollout
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: CgCorridorChart(log: log)),
                            const SizedBox(width: 12),
                            Expanded(child: RunwayPerformanceCard(log: log)),
                          ],
                        )
                      else ...[
                        CgCorridorChart(log: log),
                        const SizedBox(height: 12),
                        RunwayPerformanceCard(log: log),
                      ],
                      const SizedBox(height: 12),

                      // 4. Fuel & Dispatch Grid
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: AcarsFuelReleaseStrip(log: log)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                children: [
                                  _weights(context, log),
                                  const SizedBox(height: 12),
                                  _flight(context, log),
                                ],
                              ),
                            ),
                          ],
                        )
                      else ...[
                        AcarsFuelReleaseStrip(log: log),
                        const SizedBox(height: 12),
                        _weights(context, log),
                        const SizedBox(height: 12),
                        _flight(context, log),
                      ],
                      const SizedBox(height: 12),

                      // 5. Alerts, Notes & Delete Actions
                      if (log.alerts.isNotEmpty) ...[
                        _alerts(context, log),
                        const SizedBox(height: 12),
                      ],
                      notes,
                      const SizedBox(height: 12),
                      delete,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroHeader(BuildContext context, FlightLog log) {
    final colors = context.colors;
    final r = log.landingRating;
    final isSupersonic = log.maxMach >= 1.0 || log.supersonicSec > 0;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: colors.dividerStrong.withValues(alpha: 0.5)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          log.callSign.isEmpty ? 'SPEEDBIRD' : log.callSign,
                          style: uiText(
                            context,
                            size: 18,
                            weight: FontWeight.w900,
                            color: colors.textPrimary,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (isSupersonic) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.accent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: colors.accent.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              'SUPERSONIC',
                              style: uiText(
                                context,
                                size: 9,
                                weight: FontWeight.w900,
                                color: colors.accent,
                              ),
                            ),
                          ),
                        ],
                        if (log.registration.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            'REG: ${log.registration}',
                            style: uiText(
                              context,
                              size: 11,
                              weight: FontWeight.w700,
                              color: colors.textDim,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _route(log),
                      style: uiText(
                        context,
                        size: 12,
                        weight: FontWeight.w700,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (r != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: ratingColor(colors, r).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: ratingColor(colors, r).withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        r.label,
                        style: uiText(
                          context,
                          size: 13,
                          weight: FontWeight.w900,
                          color: ratingColor(colors, r),
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (log.touchdownFpm != null)
                        Text(
                          '${fpmText(log.touchdownFpm!)}${log.touchdownG != null ? ' · ${log.touchdownG!.toStringAsFixed(2)}G' : ''}',
                          style: uiText(
                            context,
                            size: 9,
                            weight: FontWeight.w700,
                            color: ratingColor(colors, r),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _oooi(context, log),
        ],
      ),
    );
  }

  Widget _kv(
    BuildContext context,
    String k,
    String v, {
    Color? color,
    double size = 12,
  }) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              k,
              style: uiText(
                context,
                size: 11,
                weight: FontWeight.w700,
                color: colors.textDim,
                letterSpacing: 0.6,
              ),
            ),
          ),
          Text(
            v,
            style: uiText(
              context,
              size: size,
              weight: FontWeight.w800,
              color: color ?? colors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _kg(double? v) =>
      v == null ? '--' : '${numFormat.format(v.round())} KG';

  Widget _oooi(BuildContext context, FlightLog l) {
    final colors = context.colors;
    Widget cell(String label, DateTime? t) => Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: uiText(
              context,
              size: 9,
              weight: FontWeight.w800,
              color: colors.textDim,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            zulu(t),
            style: uiText(
              context,
              size: 16,
              weight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
        ],
      ),
    );
    return EfbCard(
      title: 'OOOI (ZULU)',
      child: Column(
        children: [
          Row(
            children: [
              cell('OUT', l.blockOut),
              cell('OFF', l.takeoff),
              cell('ON', l.touchdown),
              cell('IN', l.blockIn),
            ],
          ),
          const SizedBox(height: 8),
          _kv(context, 'BLOCK TIME', hm(l.blockTime)),
          _kv(context, 'FLIGHT TIME', hm(l.flightTime)),
        ],
      ),
    );
  }

  Widget _weights(BuildContext context, FlightLog l) => EfbCard(
    title: 'WEIGHTS',
    child: Column(
      children: [
        _kv(context, 'ZFW', _kg(l.zfwKg > 0 ? l.zfwKg : null)),
        _kv(context, 'TOW', _kg(l.towKg)),
        _kv(context, 'LW', _kg(l.lwKg)),
      ],
    ),
  );

  Widget _flight(BuildContext context, FlightLog l) => EfbCard(
    title: 'FLIGHT',
    child: Column(
      children: [
        _kv(context, 'MAX MACH', 'M${l.maxMach.toStringAsFixed(2)}'),
        _kv(
          context,
          'MAX FL',
          'FL${(l.maxAltFt / 100).round().toString().padLeft(3, '0')}',
        ),
        _kv(
          context,
          'SUPERSONIC',
          hm(Duration(seconds: l.supersonicSec.round())),
        ),
        _kv(context, 'REHEAT', hm(Duration(seconds: l.reheatSec.round()))),
        _kv(
          context,
          'DISTANCE',
          '${numFormat.format(l.distanceNm.round())} NM',
        ),
        _kv(
          context,
          'CRUISE FL PLANNED',
          l.cruiseFl > 0 ? 'FL${l.cruiseFl.round()}' : '--',
        ),
      ],
    ),
  );

  Widget _alerts(BuildContext context, FlightLog l) => EfbCard(
    title: 'ALERTS',
    child: Column(
      children: [
        for (final e in l.alerts.entries) _kv(context, e.key, '×${e.value}'),
      ],
    ),
  );
}
