import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/airport.dart';

/// Airport/runway database with full offline support.
///
/// Load order:
///  1. Disk cache written by a previous successful online refresh (newest data).
///  2. Bundled asset `assets/airport_db.json.gz` (always available, generated
///     by scripts/generate_airport_db.py).
/// A background refresh from OurAirports then updates the data and the disk
/// cache when the network allows; failures are silently ignored.
class AirportDatabaseService {
  static const String airportsUrl = 'https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv';
  static const String runwaysUrl = 'https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv';
  static const String bundledAssetPath = 'assets/airport_db.json.gz';

  Map<String, Airport> airports = {};

  Future<void> initialize() async {
    final cached = await _loadFromDiskCache();
    if (cached != null && cached.isNotEmpty) {
      airports = cached;
    } else {
      final assetBytes = await rootBundle.load(bundledAssetPath);
      airports = await compute(_parseGzippedDb, assetBytes.buffer.asUint8List());
    }

    // Refresh in the background; startup never waits on the network.
    unawaited(_refreshFromNetwork());
  }

  Future<Map<String, Airport>?> _loadFromDiskCache() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;
      final bytes = await file.readAsBytes();
      return await compute(_parseGzippedDb, bytes);
    } catch (_) {
      return null; // Corrupt/unreadable cache falls back to the bundled asset.
    }
  }

  Future<void> _refreshFromNetwork() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(airportsUrl)).timeout(const Duration(seconds: 60)),
        http.get(Uri.parse(runwaysUrl)).timeout(const Duration(seconds: 60)),
      ]);
      if (responses.any((r) => r.statusCode != 200)) return;

      final result = await compute(_parseCsvsAndSerialize, [responses[0].body, responses[1].body]);
      if (result.airports.isEmpty) return;

      airports = result.airports;

      final file = await _cacheFile();
      await file.parent.create(recursive: true);
      await file.writeAsBytes(result.gzippedJson, flush: true);
    } catch (_) {
      // Offline or transient failure — keep using bundled/cached data.
    }
  }

  Future<File> _cacheFile() async {
    final appDir = await getApplicationDocumentsDirectory();
    return File('${appDir.path}/concorde_efb/airport_db.json.gz');
  }
}

// ── Isolate entry points (must be top-level for compute) ────────────────────

Map<String, Airport> _parseGzippedDb(Uint8List bytes) {
  final decoded = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
  final rawAirports = decoded['airports'] as Map<String, dynamic>;
  final out = <String, Airport>{};
  rawAirports.forEach((icao, value) {
    final a = value as List;
    out[icao] = Airport(
      icao: icao,
      name: a[0] as String,
      lat: (a[1] as num).toDouble(),
      lon: (a[2] as num).toDouble(),
      elevationFt: (a[3] as num?)?.toDouble(),
      runways: (a[4] as List)
          .map((r) => Runway(
                id: r[0] as String,
                heading: (r[1] as num).round(),
                lengthM: (r[2] as num).toDouble(),
                elevationFt: (r[3] as num?)?.toDouble(),
              ))
          .toList(),
    );
  });
  return out;
}

class _RefreshResult {
  final Map<String, Airport> airports;
  final Uint8List gzippedJson;
  const _RefreshResult(this.airports, this.gzippedJson);
}

_RefreshResult _parseCsvsAndSerialize(List<String> csvs) {
  final airports = _parseCsvs(csvs[0], csvs[1]);

  // Serialize to the same compact format as the bundled asset so both
  // paths share one parser.
  final serializable = <String, dynamic>{};
  airports.forEach((icao, a) {
    serializable[icao] = [
      a.name,
      a.lat,
      a.lon,
      a.elevationFt,
      a.runways.map((r) => [r.id, r.heading, r.lengthM, r.elevationFt]).toList(),
    ];
  });
  final raw = utf8.encode(jsonEncode({'airports': serializable}));
  return _RefreshResult(airports, Uint8List.fromList(gzip.encode(raw)));
}

Map<String, Airport> _parseCsvs(String airportsCsv, String runwaysCsv) {
  const decoder = CsvDecoder();
  final airports = <String, Airport>{};

  final airportsData = decoder.convert(airportsCsv);
  if (airportsData.isEmpty) return airports;

  final airHeader = airportsData[0].map((e) => e.toString()).toList();
  final identIdx = airHeader.indexOf('ident');
  final nameIdx = airHeader.indexOf('name');
  final latIdx = airHeader.indexOf('latitude_deg');
  final lonIdx = airHeader.indexOf('longitude_deg');
  final elevIdx = airHeader.indexOf('elevation_ft');

  for (var i = 1; i < airportsData.length; i++) {
    final row = airportsData[i];
    if (row.length <= identIdx) continue;

    final icao = row[identIdx].toString().trim().toUpperCase();
    if (icao.length != 4) continue;

    airports[icao] = Airport(
      icao: icao,
      name: row[nameIdx].toString(),
      lat: double.tryParse(row[latIdx].toString()) ?? 0.0,
      lon: double.tryParse(row[lonIdx].toString()) ?? 0.0,
      elevationFt: double.tryParse(row[elevIdx].toString()),
      runways: [],
    );
  }

  final runwaysData = decoder.convert(runwaysCsv);
  if (runwaysData.isEmpty) return airports;

  final rwHeader = runwaysData[0].map((e) => e.toString()).toList();
  final airportIdentIdx = rwHeader.indexOf('airport_ident');
  final lengthFtIdx = rwHeader.indexOf('length_ft');
  final leIdentIdx = rwHeader.indexOf('le_ident');
  final heIdentIdx = rwHeader.indexOf('he_ident');
  final leHdgIdx = rwHeader.indexOf('le_heading_degT');
  final heHdgIdx = rwHeader.indexOf('he_heading_degT');
  final leElevIdx = rwHeader.indexOf('le_elevation_ft');
  final heElevIdx = rwHeader.indexOf('he_elevation_ft');

  for (var i = 1; i < runwaysData.length; i++) {
    final row = runwaysData[i];
    if (row.length <= airportIdentIdx) continue;

    final icao = row[airportIdentIdx].toString().trim().toUpperCase();
    final airport = airports[icao];
    if (airport == null) continue;

    final lengthFt = double.tryParse(row[lengthFtIdx].toString()) ?? 0.0;
    final lengthM = lengthFt * 0.3048;

    final leIdent = row[leIdentIdx].toString().trim().toUpperCase();
    final heIdent = row[heIdentIdx].toString().trim().toUpperCase();

    if (leIdent.isNotEmpty) {
      airport.runways.add(Runway(
        id: leIdent,
        heading: (double.tryParse(row[leHdgIdx].toString()) ?? 0.0).round(),
        lengthM: lengthM,
        elevationFt: double.tryParse(row[leElevIdx].toString()),
      ));
    }

    if (heIdent.isNotEmpty) {
      airport.runways.add(Runway(
        id: heIdent,
        heading: (double.tryParse(row[heHdgIdx].toString()) ?? 0.0).round(),
        lengthM: lengthM,
        elevationFt: double.tryParse(row[heElevIdx].toString()),
      ));
    }
  }

  return airports;
}
