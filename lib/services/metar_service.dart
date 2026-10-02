import 'package:http/http.dart' as http;

/// Fetches the latest raw METAR for an ICAO, trying VATSIM first (what
/// VATSIM controllers see), then aviationweather.gov, then the NOAA/NWS
/// text feed. Returns null only when every source fails.
class MetarService {
  static const String vatsimUrl = 'https://metar.vatsim.net/{ICAO}';
  static const String aviationWeatherUrl =
      'https://aviationweather.gov/api/data/metar?ids={ICAO}&format=raw';
  static const String nwsUrl =
      'https://tgftp.nws.noaa.gov/data/observations/metar/stations/{ICAO}.TXT';

  static const _timeout = Duration(seconds: 6);

  Future<String?> fetchMetar(String icao) async {
    final code = icao.trim().toUpperCase();
    if (!RegExp(r'^[A-Z0-9]{4}$').hasMatch(code)) return null;

    for (final url in [vatsimUrl, aviationWeatherUrl, nwsUrl]) {
      final metar = await _tryFetch(url.replaceAll('{ICAO}', code), code);
      if (metar != null) return metar;
    }
    return null;
  }

  /// Returns the METAR line starting with the station code (the NWS feed
  /// prefixes a timestamp line; some sources return several lines).
  Future<String?> _tryFetch(String url, String code) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(_timeout);
      if (response.statusCode != 200) return null;
      final lines = response.body
          .split('\n')
          .map((l) => l.trim())
          .where((l) => l.isNotEmpty);
      for (final line in lines) {
        final t = line.replaceFirst(RegExp(r'^(METAR|SPECI)\s+'), '');
        if (t.startsWith(code)) return t;
      }
    } catch (_) {
      // Network/timeout -- try the next source.
    }
    return null;
  }
}

class MetarUnavailableException implements Exception {
  final String icao;
  const MetarUnavailableException(this.icao);
  @override
  String toString() => 'No METAR available for $icao';
}
