import 'dart:convert';
import 'package:http/http.dart' as http;

class SimBriefService {
  static const String baseUrl = 'https://www.simbrief.com/api/xml.fetcher.php?username={USERNAME}&json=1';

  Future<Map<String, dynamic>?> fetchLatestOFP(String username) async {
    try {
      final url = baseUrl.replaceAll('{USERNAME}', Uri.encodeComponent(username));
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      // Handle error
    }
    return null;
  }
}
