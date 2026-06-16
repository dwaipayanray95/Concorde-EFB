import 'dart:convert';
import 'package:http/http.dart' as http;

class MetarService {
  static const String vatsimUrl = 'https://metar.vatsim.net/{ICAO}';
  static const String aviationWeatherUrl = 'https://aviationweather.gov/api/data/metar?ids={ICAO}&format=raw';
  static const String nwsUrl = 'https://tgftp.nws.noaa.gov/data/observations/metar/stations/{ICAO}.TXT';

  Future<String?> fetchMetar(String icao) async {
    final icaoUpper = icao.trim().toUpperCase();
    if (icaoUpper.length != 4) return null;

    // 1. VATSIM (Primary)
    try {
      final response = await http.get(Uri.parse(vatsimUrl.replaceAll('{ICAO}', icaoUpper))).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body.trim();
      }
    } catch (_) {}

    // 2. AviationWeather
    try {
      final response = await http.get(Uri.parse(aviationWeatherUrl.replaceAll('{ICAO}', icaoUpper))).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        return response.body.trim();
      }
    } catch (_) {}

    // 3. NWS Fallback
    try {
      final response = await http.get(Uri.parse(nwsUrl.replaceAll('{ICAO}', icaoUpper))).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200 && response.body.trim().isNotEmpty) {
        final lines = response.body.split('\n');
        if (lines.length > 1) {
          return lines[1].trim(); // The actual METAR string is usually on the second line
        }
        return response.body.trim();
      }
    } catch (_) {}

    return null;
  }
}
