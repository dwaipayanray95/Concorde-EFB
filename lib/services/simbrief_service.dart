import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/concorde_models.dart';

class SimBriefService {
  static const String baseUrl =
      'https://www.simbrief.com/api/xml.fetcher.php?username={USERNAME}&json=1';

  Future<Map<String, dynamic>?> fetchLatestOFP(String username) async {
    try {
      final url = baseUrl.replaceAll(
        '{USERNAME}',
        Uri.encodeComponent(username),
      );
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (_) {
      // Fall through to null: caller surfaces the failure to the user.
    }
    return null;
  }

  /// Route fixes with coordinates from the OFP navlog, excluding the
  /// departure/arrival airports themselves. SimBrief returns `fix` as a
  /// list, or a single object for a one-fix route.
  static List<RoutePoint> navlogFixes(Map<String, dynamic> ofp) {
    final raw = ofp['navlog']?['fix'];
    final list = raw is List ? raw : (raw is Map ? [raw] : const []);
    final origin = '${ofp['origin']?['icao_code'] ?? ''}'.toUpperCase();
    final dest = '${ofp['destination']?['icao_code'] ?? ''}'.toUpperCase();
    final fixes = <RoutePoint>[];
    for (final f in list) {
      if (f is! Map) continue;
      final ident = '${f['ident'] ?? ''}'.toUpperCase();
      final lat = double.tryParse('${f['pos_lat'] ?? ''}');
      final lon = double.tryParse('${f['pos_long'] ?? ''}');
      if (lat == null || lon == null) continue;
      if (ident == origin || ident == dest) continue;
      fixes.add(RoutePoint(ident, lat, lon));
    }
    return fixes;
  }
}
