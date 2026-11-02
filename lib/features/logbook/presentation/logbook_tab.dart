import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
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
import '../../flight_monitor/data/services/lan_link.dart';
import 'logbook_format.dart';
import 'logbook_providers.dart';

bool get _isPhone =>
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS;

String _route(FlightLog l) {
  final dep = l.actualDep ?? l.plannedDep;
  final arr = l.actualArr ?? l.plannedArr;
  return '${dep.isEmpty ? '----' : dep} → ${arr.isEmpty ? '----' : arr}';
}

/// LOG tab: totals, export, flight list.
class LogbookTab extends ConsumerWidget {
  const LogbookTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final async = ref.watch(logbookProvider);
    final logs = [...?async.value]
      ..sort((a, b) => b.blockOut.compareTo(a.blockOut));

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        if (_isPhone) ...[const _SyncLine(), const SizedBox(height: 8)],
        _Totals(logs: logs),
        const SizedBox(height: 12),
        _Toolbar(logs: logs),
        const SizedBox(height: 12),
        if (async.isLoading && logs.isEmpty)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (logs.isEmpty)
          EfbFlatCard(
            padding: const EdgeInsets.all(24),
            child: Text(
              _isPhone
                  ? 'Flights are logged by the Concorde EFB desktop app and '
                        'appear here when this device connects to it.'
                  : 'No flights logged yet. Flights are recorded '
                        'automatically while the Flight Monitor is connected.',
              textAlign: TextAlign.center,
              style: uiText(context, size: 13, color: colors.textSecondary),
            ),
          )
        else
          EfbFlatCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (var i = 0; i < logs.length; i++) ...[
                  if (i > 0) Divider(height: 1, color: colors.divider),
                  _LogRow(log: logs[i]),
                ],
              ],
            ),
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
          : 'Not connected to the desktop app — showing last synced copy',
      style: uiText(context, size: 11, color: context.colors.textSecondary),
    );
  }
}

class _Totals extends StatelessWidget {
  final List<FlightLog> logs;
  const _Totals({required this.logs});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var block = Duration.zero;
    var ss = 0.0;
    for (final l in logs) {
      block += l.blockTime ?? Duration.zero;
      ss += l.supersonicSec;
    }
    final landed = logs
        .where((l) => l.touchdown != null && l.touchdownFpm != null)
        .toList();
    FlightLog? best;
    for (final l in landed) {
      if (best == null || l.touchdownFpm!.abs() < best.touchdownFpm!.abs()) {
        best = l;
      }
    }
    final avg = landed.isEmpty
        ? null
        : landed.fold<double>(0, (s, l) => s + l.touchdownFpm!.abs()) /
              landed.length;

    Widget stat(String label, String value, [String? sub]) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: uiText(
                context,
                size: 18,
                weight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (sub != null)
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: uiText(context, size: 9, color: colors.textDim),
            ),
        ],
      ),
    );

    return EfbFlatCard(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          stat('FLIGHTS', '${logs.length}'),
          stat('BLOCK HOURS', hm(block)),
          stat('SUPERSONIC', hm(Duration(seconds: ss.round()))),
          stat('AVG LANDING', avg == null ? '--' : '${avg.round()} FPM'),
          stat(
            'BEST LANDING',
            best == null ? '--' : '${best.touchdownFpm!.abs().round()} FPM',
            best == null ? null : dateText(best.blockOut),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final List<FlightLog> logs;
  const _Toolbar({required this.logs});

  Future<void> _export(BuildContext context, String ext, String content) async {
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
        fileName: 'concorde-efb-logbook.$ext',
        bytes: Uint8List.fromList(utf8.encode(content)),
        dialogTitle: 'Export logbook',
        type: FileType.custom,
        allowedExtensions: [ext],
      );
      if (saved != null) {
        messenger?.showSnackBar(
          SnackBar(content: Text('Logbook exported (${ext.toUpperCase()})')),
        );
      }
    } catch (e) {
      messenger?.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final empty = logs.isEmpty;
    return Row(
      children: [
        _ToolButton(
          icon: Icons.table_chart_outlined,
          label: 'EXPORT CSV',
          onTap: empty
              ? null
              : () =>
                    _export(context, 'csv', LogbookRepository.exportCsv(logs)),
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
      color: colors.surface,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: colors.dividerStrong.withValues(alpha: 0.7),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: fg),
              const SizedBox(width: 8),
              Text(
                label,
                style: uiText(
                  context,
                  size: 10,
                  weight: FontWeight.w900,
                  color: fg,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _pill(BuildContext context, String text, Color bg, Color fg) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: uiText(
          context,
          size: 10,
          weight: FontWeight.w900,
          color: fg,
          letterSpacing: 1,
        ),
      ),
    );

class _LogRow extends StatelessWidget {
  final FlightLog log;
  const _LogRow({required this.log});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final rating = log.landingRating;
    TextStyle s(Color c, {FontWeight w = FontWeight.w700}) =>
        uiText(context, size: 12, weight: w, color: c);

    final Widget status = (log.blockIn == null || rating == null)
        ? _pill(
            context,
            'IN PROGRESS',
            colors.dividerStrong,
            colors.textPrimary,
          )
        : _pill(
            context,
            fpmText(log.touchdownFpm!),
            ratingColor(colors, rating),
            onRatingColor(colors, rating),
          );

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LogDetailScreen(logId: log.id)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 100,
              child: Text(
                dateText(log.blockOut),
                style: s(colors.textSecondary),
              ),
            ),
            SizedBox(
              width: 84,
              child: Text(
                log.callSign.isEmpty ? '--' : log.callSign,
                overflow: TextOverflow.ellipsis,
                style: s(colors.accent, w: FontWeight.w900),
              ),
            ),
            Expanded(
              child: Text(
                _route(log),
                overflow: TextOverflow.ellipsis,
                style: s(colors.textPrimary),
              ),
            ),
            SizedBox(
              width: 56,
              child: Text(
                hm(log.blockTime),
                textAlign: TextAlign.right,
                style: s(colors.textSecondary),
              ),
            ),
            const SizedBox(width: 12),
            status,
            Icon(Icons.chevron_right, size: 18, color: colors.textDim),
          ],
        ),
      ),
    );
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

    final cards = <Widget>[
      _oooi(context, log),
      _landing(context, log),
      _fuel(context, log),
      _weights(context, log),
      _flight(context, log),
      if (log.alerts.isNotEmpty) _alerts(context, log),
    ];

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
                  final wide = c.maxWidth >= 900;
                  final notes = EfbCard(
                    title: 'NOTES',
                    child: EfbTextField(
                      label: 'Notes',
                      showLabel: false,
                      placeholder: 'Notes',
                      initialValue: log.notes,
                      keyboardType: TextInputType.multiline,
                      onChanged: _onNotes,
                    ),
                  );
                  final delete = Align(
                    alignment: Alignment.centerLeft,
                    child: _ToolButton(
                      icon: Icons.delete_outline,
                      label: 'DELETE',
                      onTap: _confirmDelete,
                    ),
                  );
                  Widget col(List<Widget> w) => Column(
                    children: [
                      for (final x in w) ...[x, const SizedBox(height: 12)],
                    ],
                  );
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                    children: [
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: col([
                                for (var i = 0; i < cards.length; i += 2)
                                  cards[i],
                              ]),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: col([
                                for (var i = 1; i < cards.length; i += 2)
                                  cards[i],
                                notes,
                              ]),
                            ),
                          ],
                        )
                      else
                        col([...cards, notes]),
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

  Widget _fuel(BuildContext context, FlightLog l) {
    final colors = context.colors;
    final actualTrip = (l.fuelTakeoffKg != null && l.fuelLandingKg != null)
        ? l.fuelTakeoffKg! - l.fuelLandingKg!
        : null;
    final margin = l.fuelLandingKg == null
        ? null
        : l.fuelLandingKg! - l.finalReserveKg;
    return EfbCard(
      title: 'FUEL',
      child: Column(
        children: [
          _kv(context, 'BLOCK OUT', _kg(l.fuelBlockOutKg)),
          _kv(context, 'TAKEOFF', _kg(l.fuelTakeoffKg)),
          _kv(context, 'LANDING', _kg(l.fuelLandingKg)),
          _kv(context, 'BLOCK IN', _kg(l.fuelBlockInKg)),
          _kv(context, 'BURNED', _kg(l.fuelBurnedKg)),
          _kv(context, 'TRIP PLANNED', _kg(l.plannedTripKg)),
          _kv(context, 'TRIP ACTUAL', _kg(actualTrip)),
          _kv(
            context,
            'LANDING VS FINAL RESERVE',
            margin == null
                ? '--'
                : '${margin >= 0 ? '+' : '−'}'
                      '${numFormat.format(margin.abs().round())} KG',
            color: margin == null
                ? null
                : (margin >= 0 ? colors.success : colors.error),
          ),
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

  Widget _landing(BuildContext context, FlightLog l) {
    final colors = context.colors;
    final r = l.landingRating;
    return EfbCard(
      title: 'LANDING',
      child: Column(
        children: [
          if (r != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  r.label,
                  style: uiText(
                    context,
                    size: 26,
                    weight: FontWeight.w900,
                    color: ratingColor(colors, r),
                    letterSpacing: 1,
                  ),
                ),
              ),
            ),
          _kv(
            context,
            'RATE OF DESCENT',
            l.touchdownFpm == null ? '--' : fpmText(l.touchdownFpm!),
          ),
          _kv(
            context,
            'VERTICAL G',
            l.touchdownG == null
                ? '--'
                : '${l.touchdownG!.toStringAsFixed(2)} G',
          ),
          _kv(
            context,
            'PITCH',
            l.touchdownPitch == null
                ? '--'
                : '${l.touchdownPitch!.toStringAsFixed(1)}°',
          ),
          _kv(
            context,
            'IAS',
            l.touchdownIas == null ? '--' : '${l.touchdownIas!.round()} KT',
          ),
          _kv(context, 'BOUNCES', '${l.bounces}'),
        ],
      ),
    );
  }

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
