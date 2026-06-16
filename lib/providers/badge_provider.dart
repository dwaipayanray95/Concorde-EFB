import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final visitorBadgeProvider = FutureProvider<String>((ref) async {
  try {
    final response = await http.get(
      Uri.parse("https://api.visitorbadge.io/api/visitors?path=https%3A%2F%2Fdwaipayanray95.github.io%2FConcorde-EFB%2F&label=EFB%20Launches&labelColor=%23111a2b&countColor=%230ea5e9"),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    ).timeout(const Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      return response.body;
    }
  } catch (_) {}
  return '';
});