/// Where a loaded flight plan came from — surfaced in the UI so the user
/// knows why the fields are populated the way they are.
enum FlightPlanSource { none, simbrief, file, manual }

/// Common shape every import path (SimBrief OFP, MSFS .pln, hand-typed
/// route) normalizes into before it's pushed onto the shared providers.
class ParsedFlightPlan {
  final String departureIcao;
  final String arrivalIcao;
  final String? alternateIcao;
  final String? departureRunway;
  final String? arrivalRunway;
  final String route;
  final double? cruiseAltFt;

  const ParsedFlightPlan({
    required this.departureIcao,
    required this.arrivalIcao,
    this.alternateIcao,
    this.departureRunway,
    this.arrivalRunway,
    this.route = '',
    this.cruiseAltFt,
  });
}

/// Parses flight-plan file formats a user might drag in from MSFS or a
/// third-party planner. Kept dependency-free (regex over the file's own
/// simple/well-known structure) rather than pulling in a full XML DOM
/// parser for a handful of fixed tag names.
class FlightPlanImportService {
  /// Parses an MSFS/FSX/P3D `.pln` file (XML). These carry
  /// `<DepartureID>` / `<DestinationID>` ICAO codes, runway details in
  /// `<DepartureDetails>` / `<ArrivalDetails>`, and `<ATCWaypoint>` nodes
  /// containing `<ICAOIdent>`, `<ATCWaypointIdent>`, or `id="..."`.
  static ParsedFlightPlan? parsePln(String xml) {
    final dep = _tag(xml, 'DepartureID');
    final dest = _tag(xml, 'DestinationID');
    if (dep == null || dest == null || dep.isEmpty || dest.isEmpty) {
      return null;
    }

    final cruiseAlt = double.tryParse(_tag(xml, 'CruisingAlt') ?? '');

    // Parse departure runway (e.g. <RunwayNumberFP>30</RunwayNumberFP> + <RunwayDesignatorFP>RIGHT</RunwayDesignatorFP> -> "30R")
    final depDetails = _tagBlock(xml, 'DepartureDetails');
    final depRwy = depDetails != null
        ? _formatRunway(
            _tag(depDetails, 'RunwayNumberFP'),
            _tag(depDetails, 'RunwayDesignatorFP'),
          )
        : null;

    // Parse arrival runway
    final arrDetails = _tagBlock(xml, 'ArrivalDetails') ?? _tagBlock(xml, 'ApproachDetails');
    final arrRwy = arrDetails != null
        ? _formatRunway(
            _tag(arrDetails, 'RunwayNumberFP'),
            _tag(arrDetails, 'RunwayDesignatorFP'),
          )
        : null;

    // Extract waypoints from <ATCWaypoint> blocks.
    // Handles both attribute style (`<ATCWaypoint id="..."/>` or `<ATCWaypoint id="...">...</ATCWaypoint>`)
    // and child tag style (`<ATCWaypoint><ICAO><ICAOIdent>...</ICAOIdent></ICAO></ATCWaypoint>`).
    final waypointMatches = RegExp(r'<ATCWaypoint\b([^>]*?)(?:>(.*?)</ATCWaypoint>|/>)', dotAll: true).allMatches(xml);
    final waypoints = <_PlnWaypoint>[];

    for (final match in waypointMatches) {
      final attrs = match.group(1) ?? '';
      final block = match.group(2) ?? '';

      // Ident can be in <ICAOIdent>, <ATCWaypointIdent>, <Ident>, or the `id="..."` attribute
      final ident = _tag(block, 'ICAOIdent') ??
          _tag(block, 'ATCWaypointIdent') ??
          _tag(block, 'Ident') ??
          RegExp(r'\bid\s*=\s*"([^"]*)"', dotAll: true).firstMatch(attrs)?.group(1);

      if (ident == null || ident.trim().isEmpty) continue;

      final airway = _tag(block, 'ATCAirway');
      waypoints.add(_PlnWaypoint(ident: ident.trim().toUpperCase(), airway: airway?.trim().toUpperCase()));
    }

    // Build the enroute string. Drop leading/trailing points if they repeat
    // the departure or destination ICAO.
    var enroute = List<_PlnWaypoint>.from(waypoints);
    if (enroute.isNotEmpty && enroute.first.ident == dep.toUpperCase()) {
      enroute.removeAt(0);
    }
    if (enroute.isNotEmpty && enroute.last.ident == dest.toUpperCase()) {
      enroute.removeLast();
    }

    // Format route as standard aviation route:
    // When consecutive fixes share an airway, represent as: FIX1 AIRWAY FIX2 ...
    final routeTokens = <String>[];
    String? currentAirway;

    for (var i = 0; i < enroute.length; i++) {
      final wp = enroute[i];
      if (wp.airway != null && wp.airway!.isNotEmpty && wp.airway != 'DIRECT') {
        if (wp.airway != currentAirway) {
          currentAirway = wp.airway;
          routeTokens.add(currentAirway!);
        }
      } else {
        currentAirway = null;
      }
      routeTokens.add(wp.ident);
    }

    final routeString = routeTokens.isEmpty
        ? enroute.map((w) => w.ident).join(' ')
        : routeTokens.join(' ');

    return ParsedFlightPlan(
      departureIcao: dep.toUpperCase(),
      arrivalIcao: dest.toUpperCase(),
      departureRunway: depRwy,
      arrivalRunway: arrRwy,
      route: routeString,
      cruiseAltFt: cruiseAlt,
    );
  }

  /// Helper to convert runway number + designator to standard ID format:
  /// e.g. ("30", "RIGHT") -> "30R", ("5", "LEFT") -> "05L", ("23", "NONE") -> "23"
  static String? _formatRunway(String? number, String? designator) {
    if (number == null || number.trim().isEmpty) return null;
    var numStr = number.trim();
    if (numStr.length == 1) {
      numStr = '0$numStr';
    }

    var suffix = '';
    if (designator != null && designator.trim().isNotEmpty) {
      final d = designator.trim().toUpperCase();
      if (d == 'RIGHT' || d == 'R') {
        suffix = 'R';
      } else if (d == 'LEFT' || d == 'L') {
        suffix = 'L';
      } else if (d == 'CENTER' || d == 'C') {
        suffix = 'C';
      }
    }
    return '$numStr$suffix';
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
    final depRwy = _tag(xml, 'DepartureRunway') ?? _attr(xml, 'Origin', 'runway');
    final arrRwy = _tag(xml, 'ArrivalRunway') ?? _attr(xml, 'Destination', 'runway');

    return ParsedFlightPlan(
      departureIcao: dep.toUpperCase(),
      arrivalIcao: dest.toUpperCase(),
      alternateIcao: alt?.toUpperCase(),
      departureRunway: depRwy?.toUpperCase(),
      arrivalRunway: arrRwy?.toUpperCase(),
      route: route.trim(),
    );
  }

  /// Parses a manually pasted route string (e.g. MSFS/VATSIM format:
  /// "OMDB/30R RIDAP M557 ... EGCC/23R" or multiple runway candidates like
  /// "OMDB/12L OMDB/30R ... EGCC/23R EGCC/05L").
  /// Extracts the departure ICAO, departure runway, arrival ICAO, arrival
  /// runway, and enroute route string.
  static ParsedFlightPlan parseManualRoute(
    String rawInput, {
    String? defaultDep,
    String? defaultArr,
    String? defaultAlt,
  }) {
    final tokens = rawInput.trim().split(RegExp(r'\s+'));
    if (tokens.isEmpty || rawInput.trim().isEmpty) {
      return ParsedFlightPlan(
        departureIcao: (defaultDep ?? '').toUpperCase(),
        arrivalIcao: (defaultArr ?? '').toUpperCase(),
        alternateIcao: defaultAlt?.toUpperCase(),
        route: '',
      );
    }

    var dep = defaultDep?.trim().toUpperCase();
    String? depRwy;
    var arr = defaultArr?.trim().toUpperCase();
    String? arrRwy;

    final tokenList = List<String>.from(tokens);

    // Forward scan from the start for departure ICAO and runway tokens
    while (tokenList.isNotEmpty) {
      final first = tokenList.first.toUpperCase();
      // Pattern 1: ICAO/RWY e.g. "OMDB/30R" or "OMDB/12L"
      final icaoRwyMatch = RegExp(r'^([A-Z]{4})/([0-9]{1,2}[LRC]?)$').firstMatch(first);
      if (icaoRwyMatch != null) {
        dep = icaoRwyMatch.group(1);
        depRwy = icaoRwyMatch.group(2);
        tokenList.removeAt(0);
        continue;
      }

      // Pattern 2: 4-letter ICAO matching departure or starting the route
      final icaoMatch = RegExp(r'^([A-Z]{4})$').firstMatch(first);
      if (icaoMatch != null) {
        final cand = icaoMatch.group(1)!;
        if (dep == null || dep.isEmpty || cand == dep) {
          dep = cand;
          tokenList.removeAt(0);
          // Check if next token is a runway like "30R" or "RW30R"
          if (tokenList.isNotEmpty) {
            final nextRwy = RegExp(r'^(?:RW)?([0-9]{1,2}[LRC]?)$').firstMatch(tokenList.first.toUpperCase());
            if (nextRwy != null) {
              depRwy = nextRwy.group(1);
              tokenList.removeAt(0);
            }
          }
          continue;
        }
      }
      break;
    }

    // Backward scan from the end for arrival ICAO and runway tokens
    while (tokenList.isNotEmpty) {
      final last = tokenList.last.toUpperCase();
      // Pattern 1: ICAO/RWY e.g. "EGCC/23R" or "EGCC/05L"
      final icaoRwyMatch = RegExp(r'^([A-Z]{4})/([0-9]{1,2}[LRC]?)$').firstMatch(last);
      if (icaoRwyMatch != null) {
        arr = icaoRwyMatch.group(1);
        arrRwy = icaoRwyMatch.group(2);
        tokenList.removeLast();
        continue;
      }

      // Pattern 2: 4-letter ICAO
      final icaoMatch = RegExp(r'^([A-Z]{4})$').firstMatch(last);
      if (icaoMatch != null) {
        final cand = icaoMatch.group(1)!;
        if (arr == null || arr.isEmpty || cand == arr) {
          arr = cand;
          tokenList.removeLast();
          continue;
        }
      }

      // Pattern 3: Standalone runway at end (e.g. "... EGCC 23R")
      final rwyMatch = RegExp(r'^(?:RW)?([0-9]{1,2}[LRC]?)$').firstMatch(last);
      if (rwyMatch != null) {
        final candidateRwy = rwyMatch.group(1);
        if (tokenList.length >= 2 && RegExp(r'^([A-Z]{4})$').hasMatch(tokenList[tokenList.length - 2].toUpperCase())) {
          arrRwy = candidateRwy;
          arr = tokenList[tokenList.length - 2].toUpperCase();
          tokenList.removeLast();
          tokenList.removeLast();
          continue;
        } else if (arr != null && arr.isNotEmpty) {
          arrRwy = candidateRwy;
          tokenList.removeLast();
          continue;
        }
      }
      break;
    }

    return ParsedFlightPlan(
      departureIcao: dep ?? '',
      arrivalIcao: arr ?? '',
      alternateIcao: defaultAlt?.toUpperCase(),
      departureRunway: depRwy,
      arrivalRunway: arrRwy,
      route: tokenList.join(' ').trim(),
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

  static String? _tagBlock(String xml, String name) {
    final m = RegExp('<$name\\b[^>]*>(.*?)</$name>', dotAll: true).firstMatch(xml);
    return m?.group(1);
  }

  static String? _attr(String xml, String tag, String attr) {
    final m = RegExp('<$tag\\b[^>]*\\b$attr\\s*=\\s*"([^"]*)"', dotAll: true).firstMatch(xml);
    return m?.group(1)?.trim();
  }
}

class _PlnWaypoint {
  final String ident;
  final String? airway;

  const _PlnWaypoint({required this.ident, this.airway});
}
