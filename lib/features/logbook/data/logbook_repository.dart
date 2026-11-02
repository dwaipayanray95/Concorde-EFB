import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'flight_log.dart';

/// One `<id>.json` per flight under `<app support>/logbook/` (never next to
/// the executable -- Program Files is read-only).
class LogbookRepository {
  final Directory? _dir;
  LogbookRepository([this._dir]);

  Future<Directory> _root() async {
    final d =
        _dir ??
        Directory(
          '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}logbook',
        );
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  File _file(Directory d, String id) => File(
    '${d.path}${Platform.pathSeparator}${id.replaceAll(RegExp(r'[^\w.-]'), '_')}.json',
  );

  /// All flights, newest block-out first. Corrupt files are skipped.
  Future<List<FlightLog>> list() async {
    final out = <FlightLog>[];
    await for (final f in (await _root()).list()) {
      if (f is! File || !f.path.endsWith('.json')) continue;
      try {
        out.add(
          FlightLog.fromJson(
            jsonDecode(await f.readAsString()) as Map<String, dynamic>,
          ),
        );
      } catch (_) {}
    }
    out.sort((a, b) => b.blockOut.compareTo(a.blockOut));
    return out;
  }

  /// Atomic: write a .tmp beside it, then rename over the target.
  Future<void> save(FlightLog log) async {
    final f = _file(await _root(), log.id);
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(log.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  Future<void> delete(String id) async {
    final f = _file(await _root(), id);
    if (await f.exists()) await f.delete();
  }

  static String exportJson(List<FlightLog> logs) =>
      const JsonEncoder.withIndent(
        '  ',
      ).convert([for (final l in logs) l.toJson()]);

  static String exportCsv(List<FlightLog> logs) {
    String q(Object? v) {
      final s = '${v ?? ''}';
      return s.contains(RegExp('[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
    }

    String hm(Duration? d) => d == null
        ? ''
        : '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';
    String z(DateTime? d) => d == null
        ? ''
        : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

    final rows = [
      'date,callsign,registration,dep,arr,block_out_z,block_in_z,block_time,'
          'flight_time,fuel_burned_kg,landing_fpm,landing_g,rating,notes',
      for (final l in logs)
        [
          l.blockOut.toIso8601String().substring(0, 10),
          l.callSign,
          l.registration,
          l.actualDep ?? l.plannedDep,
          l.actualArr ?? l.plannedArr,
          z(l.blockOut),
          z(l.blockIn),
          hm(l.blockTime),
          hm(l.flightTime),
          l.fuelBurnedKg?.round(),
          l.touchdownFpm?.round(),
          l.touchdownG?.toStringAsFixed(2),
          l.landingRating?.label,
          l.notes,
        ].map(q).join(','),
    ];
    return '${rows.join('\n')}\n';
  }
}
