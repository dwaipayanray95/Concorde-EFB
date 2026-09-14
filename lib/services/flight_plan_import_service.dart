/// Where a loaded flight plan came from — surfaced in the UI so the user
/// knows why the fields are populated the way they are.
enum FlightPlanSource { none, simbrief, file, manual }

/// Common shape every import path (SimBrief OFP, MSFS .pln, hand-typed
/// route) normalizes into before it's pushed onto the shared providers.
class ParsedFlightPlan {
  final String departureIcao;
  final String arrivalIcao;
  final String? alternateIcao;
  final String route;
  final double? cruiseAltFt;

  const ParsedFlightPlan({
    required this.departureIcao,
    required this.arrivalIcao,
    this.alternateIcao,
    this.route = '',
    this.cruiseAltFt,
  });
}

/// Parses flight-plan file formats a user might drag in from MSFS or a
/// third-party planner. Kept dependency-free (regex over the file's own
/// simple/well-known structure) rather than pulling in a full XML DOM
/// parser for a handful of fixed tag names.
class FlightPlanImportService {
  /// Parses an MSFS/FSX/P3D `.pln` file (XML). These always carry
  /// `<DepartureID>` / `<DestinationID>` ICAO codes and a `<CruisingAlt>`,
  /// plus one `<ATCWaypoint id="...">` per point on the route including
  /// the departure and arrival airports themselves.
  static ParsedFlightPlan? parsePln(String xml) {
    final dep = _tag(xml, 'DepartureID');
    final dest = _tag(xml, 'DestinationID');
    if (dep == null || dest == null || dep.isEmpty || dest.isEmpty) {
      return null;
    }

    final cruiseAlt = double.tryParse(_tag(xml, 'CruisingAlt') ?? '');

    final waypointIds = RegExp(r'<ATCWaypoint id="([^"]*)"')
        .allMatches(xml)
        .map((m) => m.group(1)!.trim())
        .where((id) => id.isNotEmpty)
        .toList();

    // Drop the leading/trailing entries when they just repeat the
    // departure/destination airport identifiers, so the route string is
    // the enroute fixes only.
    var enroute = List<String>.from(waypointIds);
    if (enroute.isNotEmpty && enroute.first.toUpperCase() == dep.toUpperCase()) {
      enroute.removeAt(0);
    }
    if (enroute.isNotEmpty && enroute.last.toUpperCase() == dest.toUpperCase()) {
      enroute.removeLast();
    }

    return ParsedFlightPlan(
      departureIcao: dep.toUpperCase(),
      arrivalIcao: dest.toUpperCase(),
      route: enroute.join(' '),
      cruiseAltFt: cruiseAlt,
    );
  }

  /// Simfly/PFPX/generic route-XML exports commonly use
  /// `<Origin>`/`<Destination>` (ICAO attributes or text) instead of
  /// `.pln`'s `DepartureID`/`DestinationID`. Tried as a fallback when
  /// `.pln`-style tags aren't present.
  static ParsedFlightPlan? parseGenericRouteXml(String xml) {
    final dep = _tag(xml, 'Origin') ?? _attr(xml, 'Origin', 'icao_code') ?? _attr(xml, 'Origin', 'id');
    final dest = _tag(xml, 'Destination') ?? _attr(xml, 'Destination', 'icao_code') ?? _attr(xml, 'Destination', 'id');
    if (dep == null || dest == null || dep.isEmpty || dest.isEmpty) return null;

    final route = _tag(xml, 'Route') ?? '';
    final alt = _tag(xml, 'Alternate') ?? _attr(xml, 'Alternate', 'icao_code');

    return ParsedFlightPlan(
      departureIcao: dep.toUpperCase(),
      arrivalIcao: dest.toUpperCase(),
      alternateIcao: alt?.toUpperCase(),
      route: route.trim(),
    );
  }

  /// Tries every known XML shape against file content — used by the file
  /// import flow, which doesn't know in advance whether the user picked a
  /// `.pln` or some other planner's route XML.
  static ParsedFlightPlan? parseAnyXml(String content) {
    return parsePln(content) ?? parseGenericRouteXml(content);
  }

  static String? _tag(String xml, String name) {
    final m = RegExp('<$name>([^<]*)</$name>').firstMatch(xml);
    return m?.group(1)?.trim();
  }

  static String? _attr(String xml, String tag, String attr) {
    final m = RegExp('<$tag\\b[^>]*\\b$attr="([^"]*)"').firstMatch(xml);
    return m?.group(1)?.trim();
  }
}
