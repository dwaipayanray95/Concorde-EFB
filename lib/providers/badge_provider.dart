import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final visitorCountProvider = FutureProvider<int>((ref) async {
  try {
    const path = "https://dwaipayanray95.github.io/Concorde-EFB/";
    final encodedPath = Uri.encodeComponent(path);
    final badgeUrl = "https://api.visitorbadge.io/api/visitors?path=$encodedPath";

    final response = await http.get(
      Uri.parse(badgeUrl),
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Cache-Control': 'no-cache',
        'Pragma': 'no-cache',
      },
    ).timeout(const Duration(seconds: 10));
    
    if (response.statusCode == 200) {
      final svg = response.body;
      
      // Look for the count number in the SVG.
      // The API usually returns two <text> blocks: one for the label, one for the count.
      // We look for any text block containing numbers and commas.
      final regExp = RegExp(r'<text[^>]*>([\d,]+)</text>');
      final matches = regExp.allMatches(svg);
      
      if (matches.isNotEmpty) {
        // The last numeric match is the visitor count.
        final countStr = matches.last.group(1)!.replaceAll(',', '');
        final count = int.tryParse(countStr);
        if (count != null && count > 0) return count;
      }
    }
  } catch (_) {}
  
  // Fallback: If blocked or error, return a realistic "last known" or 0
  return 0;
});
