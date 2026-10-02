import 'dart:math' as math;
import '../models/concorde_models.dart';
export '../models/concorde_models.dart' show MetarQnh;

class MetarParse {
  final double? windDirDeg;
  final double? windSpeedKt;
  final double? windGustKt;

  const MetarParse({this.windDirDeg, this.windSpeedKt, this.windGustKt});
}

class WindComponentSummary {
  final double? headwindKt;
  final double? crosswindKt;
  final String? crosswindDir; // "L" or "R"

  const WindComponentSummary({
    this.headwindKt,
    this.crosswindKt,
    this.crosswindDir,
  });
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
      return MetarQnh(
        unit: 'inHg',
        value: double.parse(matchInHg.group(1)!) / 100,
      );
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

  /// The METAR body before any remarks / trend groups, so remark-only
  /// tokens (e.g. "SLP", "SNOCLO" decoding) don't get read as weather.
  static String _body(String raw) {
    final cut = RegExp(r'\s(RMK|TEMPO|BECMG|NOSIG)\b').firstMatch(raw);
    return cut == null ? raw : raw.substring(0, cut.start);
  }

  static final _wxToken = RegExp(
    r'^(?:[-+]|VC)?(?:MI|PR|BC|DR|BL|SH|TS|FZ)?'
    r'(?:DZ|RA|SN|SG|IC|PL|GR|GS|UP|BR|FG|FU|VA|DU|SA|HZ|PY|PO|SQ|FC|SS|DS)+$',
  );

  /// Present-weather groups (e.g. "-RA", "+TSRA", "FZFG", "BR", "VCTS").
  /// Only tokens after the DDHHMMZ group are considered, so the station
  /// identifier can never be mistaken for a weather code.
  static List<String> parsePresentWeather(String raw) {
    final tokens = _body(raw).split(RegExp(r'\s+'));
    final timeIdx = tokens.indexWhere((t) => RegExp(r'^\d{6}Z$').hasMatch(t));
    return tokens
        .skip(timeIdx + 1)
        .where(
          (t) =>
              _wxToken.hasMatch(t) || RegExp(r'^(?:[-+]|VC)?TS$').hasMatch(t),
        )
        .toList();
  }

  /// Recent-weather groups (RERA, RESN, ...) without the "RE" prefix.
  static List<String> parseRecentWeather(String raw) {
    return RegExp(
      r'\bRE([A-Z]{2,6})\b',
    ).allMatches(_body(raw)).map((m) => m.group(1)!).toList();
  }

  /// Runway surface state implied by the METAR: frozen/solid precipitation
  /// or freezing rain/drizzle -> contaminated; rain/drizzle (now or
  /// recent) -> wet; otherwise dry.
  static RunwayCondition inferRunwayCondition(String raw) {
    final wx = [...parsePresentWeather(raw), ...parseRecentWeather(raw)];
    bool any(List<String> codes) =>
        wx.any((t) => codes.any((c) => t.contains(c)));
    if (any(['SN', 'SG', 'PL', 'GR', 'GS', 'IC', 'FZRA', 'FZDZ'])) {
      return RunwayCondition.contaminated;
    }
    if (any(['RA', 'DZ', 'UP'])) return RunwayCondition.wet;
    return RunwayCondition.dry;
  }

  /// Observation time (UTC) from the DDHHMMZ group, resolved against [now]
  /// (a day-of-month later than today belongs to the previous month).
  static DateTime? parseObservationTime(String raw, {DateTime? now}) {
    final m = RegExp(r'\b(\d{2})(\d{2})(\d{2})Z\b').firstMatch(raw);
    if (m == null) return null;
    final day = int.parse(m.group(1)!);
    final hour = int.parse(m.group(2)!);
    final minute = int.parse(m.group(3)!);
    if (day < 1 || day > 31 || hour > 23 || minute > 59) return null;
    final ref = (now ?? DateTime.now()).toUtc();
    var obs = DateTime.utc(ref.year, ref.month, day, hour, minute);
    if (obs.isAfter(ref.add(const Duration(hours: 1)))) {
      obs = DateTime.utc(ref.year, ref.month - 1, day, hour, minute);
    }
    return obs;
  }

  /// Minutes since the observation, or null if the time can't be parsed.
  static int? metarAgeMinutes(String raw, {DateTime? now}) {
    final obs = parseObservationTime(raw, now: now);
    if (obs == null) return null;
    return (now ?? DateTime.now()).toUtc().difference(obs).inMinutes;
  }

  static const _wxNames = {
    'TS': 'THUNDERSTORM',
    'DZ': 'DRIZZLE',
    'RA': 'RAIN',
    'SN': 'SNOW',
    'SG': 'SNOW GRAINS',
    'PL': 'ICE PELLETS',
    'GR': 'HAIL',
    'GS': 'SMALL HAIL',
    'IC': 'ICE CRYSTALS',
    'UP': 'PRECIP',
    'BR': 'MIST',
    'FG': 'FOG',
    'HZ': 'HAZE',
    'FU': 'SMOKE',
    'SQ': 'SQUALLS',
    'DU': 'DUST',
    'SA': 'SAND',
  };

  static String _describeWx(String token) {
    var t = token;
    final parts = <String>[];
    if (t.startsWith('+')) {
      parts.add('HEAVY');
      t = t.substring(1);
    } else if (t.startsWith('-')) {
      parts.add('LIGHT');
      t = t.substring(1);
    }
    if (t.startsWith('VC')) {
      t = t.substring(2);
    }
    if (t.startsWith('FZ')) {
      parts.add('FREEZING');
      t = t.substring(2);
    } else if (t.startsWith('SH')) {
      parts.add('SHOWERS OF');
      t = t.substring(2);
    }
    for (var i = 0; i + 2 <= t.length; i += 2) {
      final name = _wxNames[t.substring(i, i + 2)];
      if (name != null) parts.add(name);
    }
    if (token.contains('VC')) parts.add('IN VICINITY');
    return parts.join(' ');
  }

  /// Human-readable sky + weather summary, e.g. "LIGHT RAIN · OVERCAST
  /// 800 FT". Present weather first (most operationally relevant), then
  /// the lowest significant cloud layer.
  static String parseWeatherSummary(String raw) {
    final body = _body(raw);
    final wx = parsePresentWeather(
      body,
    ).map(_describeWx).where((s) => s.isNotEmpty);

    String sky;
    final layers = RegExp(
      r'\b(FEW|SCT|BKN|OVC|VV)(\d{3})(CB|TCU)?\b',
    ).allMatches(body).toList();
    if (body.contains('CAVOK')) {
      sky = 'CAVOK';
    } else if (RegExp(r'\b(SKC|CLR|NSC|NCD)\b').hasMatch(body)) {
      sky = 'CLEAR';
    } else if (layers.isEmpty) {
      sky = '';
    } else {
      const names = {
        'FEW': 'FEW',
        'SCT': 'SCATTERED',
        'BKN': 'BROKEN',
        'OVC': 'OVERCAST',
        'VV': 'SKY OBSCURED',
      };
      // Ceiling layer if any (BKN/OVC/VV), else the lowest layer.
      final ceiling = layers.firstWhere(
        (m) => m.group(1) != 'FEW' && m.group(1) != 'SCT',
        orElse: () => layers.first,
      );
      final ft = int.parse(ceiling.group(2)!) * 100;
      final cb = layers.any((m) => m.group(3) == 'CB') ? ' · CB' : '';
      sky = '${names[ceiling.group(1)]} $ft FT$cb';
    }
    final parts = [...wx, if (sky.isNotEmpty) sky];
    return parts.isEmpty ? 'UNKNOWN' : parts.join(' · ');
  }

  static WindComponentSummary calculateComponents(
    double? windDirDeg,
    double? windSpeedKt,
    double runwayHeadingDeg,
  ) {
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
