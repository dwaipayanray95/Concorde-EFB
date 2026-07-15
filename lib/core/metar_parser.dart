import 'dart:math' as math;

class MetarParse {
  final double? windDirDeg;
  final double? windSpeedKt;
  final double? windGustKt;

  const MetarParse({this.windDirDeg, this.windSpeedKt, this.windGustKt});
}

class MetarQnh {
  final String unit; // hPa or inHg
  final double value;

  const MetarQnh({required this.unit, required this.value});
}

class WindComponentSummary {
  final double? headwindKt;
  final double? crosswindKt;
  final String? crosswindDir; // "L" or "R"

  const WindComponentSummary({this.headwindKt, this.crosswindKt, this.crosswindDir});
}

class MetarParser {
  static MetarParse parseWind(String raw) {
    final regex = RegExp(r'\b(\d{3}|VRB)(\d{2,3})(?:G(\d{2,3}))?(KT|MPS)\b');
    final match = regex.firstMatch(raw);
    if (match == null) return const MetarParse();

    final dirStr = match.group(1);
    final spdStr = match.group(2);
    final gstStr = match.group(3);
    final unit = match.group(4);

    double? dirDeg = dirStr == 'VRB' ? null : double.tryParse(dirStr ?? '');
    double? spd = double.tryParse(spdStr ?? '');
    double? gst = gstStr != null ? double.tryParse(gstStr) : null;

    if (unit == 'MPS') {
      spd = spd != null ? spd * 1.94384 : null;
      gst = gst != null ? gst * 1.94384 : null;
    }

    return MetarParse(windDirDeg: dirDeg, windSpeedKt: spd, windGustKt: gst);
  }

  static MetarQnh? parseQnh(String raw) {
    final qnhHpaRegex = RegExp(r'\bQ(\d{4})\b');
    final matchHpa = qnhHpaRegex.firstMatch(raw);
    if (matchHpa != null) {
      return MetarQnh(unit: 'hPa', value: double.parse(matchHpa.group(1)!));
    }

    final qnhInHgRegex = RegExp(r'\bA(\d{4})\b');
    final matchInHg = qnhInHgRegex.firstMatch(raw);
    if (matchInHg != null) {
      return MetarQnh(unit: 'inHg', value: double.parse(matchInHg.group(1)!) / 100);
    }
    return null;
  }

  static double? parseTempC(String raw) {
    final regex = RegExp(r'\b(M)?(\d{2})/(M)?(\d{2})\b');
    final match = regex.firstMatch(raw);
    if (match == null) return null;

    final isMinus = match.group(1) == 'M';
    final tempStr = match.group(2);
    if (tempStr == null) return null;

    double temp = double.parse(tempStr);
    return isMinus ? -temp : temp;
  }

  static double? parseVisibilityKm(String raw) {
    if (raw.contains('CAVOK')) return 10.0;

    // Statute miles first (US format), handling whole ("10SM"),
    // fraction ("1/2SM"), mixed ("1 1/2SM") and "less than" ("M1/4SM") forms.
    final smRegex = RegExp(r'(?:^|\s)M?(?:(\d+)\s)?(\d+)(?:/(\d+))?SM\b');
    final matchSm = smRegex.firstMatch(raw);
    if (matchSm != null) {
      final whole = double.tryParse(matchSm.group(1) ?? '') ?? 0.0;
      final numerator = double.parse(matchSm.group(2)!);
      final denominator = double.tryParse(matchSm.group(3) ?? '');
      final miles = denominator != null && denominator > 0
          ? whole + numerator / denominator
          : whole + numerator;
      return miles * 1.60934;
    }

    // Metric visibility: standalone 4-digit group (optionally with NDV),
    // anchored on whitespace so wind/time/QNH groups can't match.
    final mRegex = RegExp(r'(?:^|\s)(\d{4})(?:NDV)?(?=\s|$)');
    final matchM = mRegex.firstMatch(raw);
    if (matchM != null) {
      final val = double.parse(matchM.group(1)!);
      if (val == 9999) return 10.0;
      return val / 1000.0;
    }
    return null;
  }

  /// Lowest broken/overcast/obscured layer in feet AGL, or null if none.
  static double? parseCeilingFt(String raw) {
    final regex = RegExp(r'\b(?:BKN|OVC|VV)(\d{3})');
    double? lowest;
    for (final m in regex.allMatches(raw)) {
      final ft = double.parse(m.group(1)!) * 100;
      if (lowest == null || ft < lowest) lowest = ft;
    }
    return lowest;
  }

  static String parseFlightCategory(String raw) {
    final vis = parseVisibilityKm(raw) ?? 10.0;
    final ceiling = parseCeilingFt(raw) ?? double.infinity;
    // Standard US categories: worse of visibility and ceiling wins.
    if (vis < 1.6 || ceiling < 500) return 'LIFR';
    if (vis < 4.8 || ceiling < 1000) return 'IFR';
    if (vis < 8.0 || ceiling <= 3000) return 'MVFR';
    return 'VFR';
  }

  static String parseWeatherSummary(String raw) {
    if (raw.contains('BKN') || raw.contains('OVC')) return 'BROKEN CLOUDS';
    if (raw.contains('SCT')) return 'SCATTERED CLOUDS';
    if (raw.contains('FEW')) return 'FEW CLOUDS';
    if (raw.contains('CAVOK') || raw.contains('CLR') || raw.contains('SKC')) return 'CLEAR';
    return 'UNKNOWN';
  }

  static WindComponentSummary calculateComponents(double? windDirDeg, double? windSpeedKt, double runwayHeadingDeg) {
    if (windDirDeg == null || windSpeedKt == null) {
      return const WindComponentSummary();
    }
    final theta = (((windDirDeg - runwayHeadingDeg) % 360) + 360) % 360;
    final rad = theta * math.pi / 180;
    final head = windSpeedKt * math.cos(rad);
    final crossSigned = windSpeedKt * math.sin(rad);

    return WindComponentSummary(
      headwindKt: (head * 10).round() / 10,
      crosswindKt: (crossSigned.abs() * 10).round() / 10,
      crosswindDir: crossSigned == 0 ? null : (crossSigned > 0 ? 'R' : 'L'),
    );
  }
}
