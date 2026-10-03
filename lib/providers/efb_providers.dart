import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/airport_database_service.dart';
import '../core/concorde_logic.dart';
import '../models/concorde_models.dart';
import '../models/airport.dart';
import '../core/concorde_constants.dart';
import '../services/metar_service.dart';
import '../services/flight_plan_import_service.dart';

final airportDbProvider = FutureProvider<AirportDatabaseService>((ref) async {
  final service = AirportDatabaseService();
  await service.initialize();
  return service;
});

// --- Flight Plan State ---
class DepartureIcaoNotifier extends Notifier<String> {
  @override
  String build() => 'EGLL';
  void set(String val) {
    final v = val.trim().toUpperCase();
    if (v == state) return;
    state = v;
    // A new airport always starts from the automatic runway pick.
    ref.read(departureRunwayIdProvider.notifier).resetToAuto();
  }
}

final departureIcaoProvider = NotifierProvider<DepartureIcaoNotifier, String>(
  DepartureIcaoNotifier.new,
);

class ArrivalIcaoNotifier extends Notifier<String> {
  @override
  String build() => 'KJFK';
  void set(String val) {
    final v = val.trim().toUpperCase();
    if (v == state) return;
    state = v;
    // A new airport always starts from the automatic runway pick.
    ref.read(arrivalRunwayIdProvider.notifier).resetToAuto();
  }
}

final arrivalIcaoProvider = NotifierProvider<ArrivalIcaoNotifier, String>(
  ArrivalIcaoNotifier.new,
);

class AlternateIcaoNotifier extends Notifier<String> {
  @override
  String build() => 'KBOS';
  void set(String val) {
    final v = val.trim().toUpperCase();
    if (v == state) return;
    state = v;
    // A planned alternate route distance belongs to the old alternate.
    ref.read(alternateRouteDistanceProvider.notifier).set(null);
  }
}

/// Alternate route distance from the flight plan (SimBrief), if known.
/// When null, the alternate distance is estimated from the great circle
/// plus airway/terminal allowances.
class AlternateRouteDistanceNotifier extends Notifier<double?> {
  @override
  double? build() => null;
  void set(double? val) => state = val;
}

final alternateRouteDistanceProvider =
    NotifierProvider<AlternateRouteDistanceNotifier, double?>(
      AlternateRouteDistanceNotifier.new,
    );

/// The imported route's fixes (SimBrief navlog / .pln), if any.
class PlannedRouteNotifier extends Notifier<PlannedRoute?> {
  @override
  PlannedRoute? build() => null;
  void set(PlannedRoute? val) => state = val;
}

final plannedRouteProvider =
    NotifierProvider<PlannedRouteNotifier, PlannedRoute?>(
      PlannedRouteNotifier.new,
    );

/// Full route polyline DEP -> fixes -> ARR, or null when there is no
/// imported route for the current airport pair (e.g. the user typed new
/// ICAOs after importing).
final routePolylineProvider = Provider<List<RoutePoint>?>((ref) {
  final route = ref.watch(plannedRouteProvider);
  final dep = ref.watch(depAirportProvider);
  final arr = ref.watch(arrAirportProvider);
  if (route == null || dep == null || arr == null) return null;
  if (route.departureIcao != dep.icao || route.arrivalIcao != arr.icao) {
    return null;
  }
  if (route.fixes.isEmpty) return null;
  return [
    RoutePoint(dep.icao, dep.lat, dep.lon),
    ...route.fixes,
    RoutePoint(arr.icao, arr.lat, arr.lon),
  ];
});

/// Route distance / great-circle distance for the current plan (how much
/// longer the flown route is). Used to turn any great-circle figure into a
/// route figure when no fix-by-fix route is available.
final routeFactorProvider = Provider<double>((ref) {
  final dep = ref.watch(depAirportProvider);
  final arr = ref.watch(arrAirportProvider);
  final planned = ref.watch(plannedDistanceProvider);
  if (dep == null || arr == null) return ConcordeLogic.routeInefficiencyFactor;
  final gc = ConcordeLogic.greatCircleNM(dep.lat, dep.lon, arr.lat, arr.lon);
  if (gc < 1 || planned <= 0) return ConcordeLogic.routeInefficiencyFactor;
  return (planned / gc).clamp(1.0, 1.6);
});

final alternateIcaoProvider = NotifierProvider<AlternateIcaoNotifier, String>(
  AlternateIcaoNotifier.new,
);

class PlannedDistanceNotifier extends Notifier<double> {
  @override
  double build() => 3000.0;
  void set(double val) => state = val;
}

final plannedDistanceProvider =
    NotifierProvider<PlannedDistanceNotifier, double>(
      PlannedDistanceNotifier.new,
    );

/// Where the currently loaded flight plan came from (SimBrief / a .pln or
/// route-XML file / hand-typed) -- purely informational, shown as a badge
/// on the Flight Plan card.
class FlightPlanSourceNotifier extends Notifier<FlightPlanSource> {
  @override
  FlightPlanSource build() => FlightPlanSource.none;
  void set(FlightPlanSource val) => state = val;
}

final flightPlanSourceProvider =
    NotifierProvider<FlightPlanSourceNotifier, FlightPlanSource>(
      FlightPlanSourceNotifier.new,
    );

// --- SimBrief State ---
class SimbriefUserNotifier extends Notifier<String> {
  SharedPreferences? _prefs;

  @override
  String build() {
    _loadPrefs();
    return '';
  }

  void _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString('simbrief_username');
    // Only apply the saved value if the user hasn't typed anything yet,
    // so a slow prefs load can't clobber live input.
    if (saved != null && saved.isNotEmpty && state.isEmpty) {
      state = saved;
    }
  }

  void set(String val) async {
    state = val;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString('simbrief_username', val);
  }
}

final simbriefUserProvider = NotifierProvider<SimbriefUserNotifier, String>(
  SimbriefUserNotifier.new,
);

class CallSignNotifier extends Notifier<String> {
  @override
  String build() => '--';
  void set(String val) => state = val;
}

final callSignProvider = NotifierProvider<CallSignNotifier, String>(
  CallSignNotifier.new,
);

class RegistrationNotifier extends Notifier<String> {
  @override
  String build() => '--';
  void set(String val) => state = val;
}

final registrationProvider = NotifierProvider<RegistrationNotifier, String>(
  RegistrationNotifier.new,
);

class SimbriefLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}

final simbriefLoadingProvider = NotifierProvider<SimbriefLoadingNotifier, bool>(
  SimbriefLoadingNotifier.new,
);

class SimbriefRouteNotifier extends Notifier<String> {
  @override
  String build() => '--';
  void set(String val) => state = val;
}

final simbriefRouteProvider = NotifierProvider<SimbriefRouteNotifier, String>(
  SimbriefRouteNotifier.new,
);

class SimbriefLoadedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}

final simbriefLoadedProvider = NotifierProvider<SimbriefLoadedNotifier, bool>(
  SimbriefLoadedNotifier.new,
);

// --- Runways State ---
/// Default runway from the current METAR (gust-inclusive components):
///  1. no tailwind (else the least tailwind),
///  2. crosswind at most 15 kt when such a runway exists,
///  3. longest (Concorde is runway-length limited).
/// With no usable wind, simply the longest. '' if the airport has no
/// runways / isn't resolved yet.
String bestRunwayId(Airport? airport, String metar) {
  if (airport == null || airport.runways.isEmpty) return '';
  RunwayEnvironmentInputs env(Runway r) => ConcordeLogic.runwayEnvFromMetar(
    metar: metar,
    runwayHeadingDeg: r.heading.toDouble(),
  );
  double tail(Runway r) {
    final t = env(r).tailwindKt ?? 0.0;
    return t > 0.5 ? t : 0.0;
  }

  int strongCross(Runway r) => (env(r).crosswindKt ?? 0.0) > 15 ? 1 : 0;
  final ranked = [...airport.runways]
    ..sort((a, b) {
      final t = tail(a).compareTo(tail(b));
      if (t != 0) return t;
      final c = strongCross(a).compareTo(strongCross(b));
      if (c != 0) return c;
      return b.lengthM.compareTo(a.lengthM);
    });
  return ranked.first.id;
}

/// Selected runway for one leg. Picks [bestRunwayId] automatically and
/// re-picks it when the airport or the METAR changes -- until the pilot
/// (or a SimBrief import) chooses a runway, which is then kept for that
/// airport. A new airport always resets to automatic.
///
/// The automatic pick also matters for correctness: the dropdown's items
/// are rebuilt from the new airport, and an id from the old airport would
/// trip DropdownButton's "exactly one matching item" assertion.
abstract class _RunwayIdNotifier extends Notifier<String> {
  Provider<Airport?> get airport;
  FutureProvider<String> get metar;
  bool _manual = false;

  String _auto() =>
      bestRunwayId(ref.read(airport), ref.read(metar).value ?? '');

  @override
  String build() {
    ref.listen(airport, (previous, next) {
      if (next?.icao == previous?.icao) return;
      final keep =
          _manual && (next?.runways.any((r) => r.id == state) ?? false);
      if (!keep) {
        _manual = false;
        state = _auto();
      }
    });
    ref.listen(metar, (_, _) {
      if (!_manual) state = _auto();
    });
    return _auto();
  }

  /// Back to automatic selection (used when the ICAO is retyped).
  void resetToAuto() {
    _manual = false;
    state = _auto();
  }

  void set(String val) {
    _manual = true;
    state = val;
  }
}

class DepartureRunwayIdNotifier extends _RunwayIdNotifier {
  @override
  Provider<Airport?> get airport => depAirportProvider;
  @override
  FutureProvider<String> get metar => departureMetarFutureProvider;
}

final departureRunwayIdProvider =
    NotifierProvider<DepartureRunwayIdNotifier, String>(
      DepartureRunwayIdNotifier.new,
    );

class ArrivalRunwayIdNotifier extends _RunwayIdNotifier {
  @override
  Provider<Airport?> get airport => arrAirportProvider;
  @override
  FutureProvider<String> get metar => arrivalMetarFutureProvider;
}

final arrivalRunwayIdProvider =
    NotifierProvider<ArrivalRunwayIdNotifier, String>(
      ArrivalRunwayIdNotifier.new,
    );
// --- Runways State ---
// --- Derived Airport Providers ---
final depAirportProvider = Provider<Airport?>((ref) {
  final db = ref.watch(airportDbProvider).value;
  final icao = ref.watch(departureIcaoProvider);
  return db?.airports[icao];
});

final arrAirportProvider = Provider<Airport?>((ref) {
  final db = ref.watch(airportDbProvider).value;
  final icao = ref.watch(arrivalIcaoProvider);
  return db?.airports[icao];
});

/// METARs are refreshed automatically every [metarRefreshInterval] while
/// watched, and whenever the ICAO changes.
const metarRefreshInterval = Duration(minutes: 10);

Future<String> _fetchMetar(Ref ref, String icao) async {
  final timer = Timer(metarRefreshInterval, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  if (icao.isEmpty) return '';
  final metar = await MetarService().fetchMetar(icao);
  // Surface a failure as an error state (UI shows OFFLINE + retry) rather
  // than an empty string that looks like "no weather".
  if (metar == null) throw MetarUnavailableException(icao);
  return metar;
}

final departureMetarFutureProvider = FutureProvider<String>(
  (ref) => _fetchMetar(ref, ref.watch(departureIcaoProvider)),
);

final arrivalMetarFutureProvider = FutureProvider<String>(
  (ref) => _fetchMetar(ref, ref.watch(arrivalIcaoProvider)),
);

final flightDirectionProvider = Provider<String?>((ref) {
  final dep = ref.watch(depAirportProvider);
  final arr = ref.watch(arrAirportProvider);
  if (dep == null || arr == null) return null;
  return ConcordeLogic.inferDirectionEW(dep.lat, dep.lon, arr.lat, arr.lon);
});

// --- Cruise & Payload State ---
class CruiseFLNotifier extends Notifier<double> {
  @override
  double build() {
    // Flight direction resolves asynchronously (airport DB load). If the
    // user edits cruise FL before it's known, re-snap once direction
    // becomes available so the FL matches the correct E/W RVSM table.
    ref.listen(flightDirectionProvider, (previous, next) {
      if (next != null && next != previous) {
        state = ConcordeLogic.snapToNonRvsm(state, next);
      }
    });
    // ref.listen above only reacts to FUTURE transitions -- if the
    // departure/arrival ICAOs (and therefore direction) were already set
    // before this notifier is first built (e.g. the user picked both
    // airports before ever opening the Cruise & Fuel card), the direction
    // is already resolved right now and no "change" will ever fire to
    // correct the default. Snap eagerly against whatever's already known.
    return ConcordeLogic.snapToNonRvsm(
      590.0,
      ref.read(flightDirectionProvider),
    );
  }

  void set(double val, String? direction) {
    state = ConcordeLogic.snapToNonRvsm(val, direction);
  }
}

final cruiseFLProvider = NotifierProvider<CruiseFLNotifier, double>(
  CruiseFLNotifier.new,
);

class TaxiFuelNotifier extends Notifier<double> {
  @override
  double build() => 2500.0;
  void set(double val) => state = val;
}

final taxiFuelProvider = NotifierProvider<TaxiFuelNotifier, double>(
  TaxiFuelNotifier.new,
);

class ContingencyPctNotifier extends Notifier<double> {
  @override
  double build() => 5.0;
  void set(double val) => state = val;
}

final contingencyPctProvider = NotifierProvider<ContingencyPctNotifier, double>(
  ContingencyPctNotifier.new,
);

class FinalReserveFuelNotifier extends Notifier<double> {
  @override
  double build() => ConcordeConstants.fuel.defaultFinalReserveKg;
  void set(double val) => state = val;
}

final finalReserveFuelProvider =
    NotifierProvider<FinalReserveFuelNotifier, double>(
      FinalReserveFuelNotifier.new,
    );

class ExtraFuelNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void set(double val) => state = val;
}

final extraFuelProvider = NotifierProvider<ExtraFuelNotifier, double>(
  ExtraFuelNotifier.new,
);

class PaxCountNotifier extends Notifier<int> {
  @override
  int build() => 100;
  void set(int val) => state = val;
}

final paxCountProvider = NotifierProvider<PaxCountNotifier, int>(
  PaxCountNotifier.new,
);

// --- Derived Providers ---

final altAirportProvider = Provider<Airport?>((ref) {
  final db = ref.watch(airportDbProvider).value;
  final icao = ref.watch(alternateIcaoProvider);
  return db?.airports[icao];
});

final departureRunwayProvider = Provider<Runway?>((ref) {
  final airport = ref.watch(depAirportProvider);
  final rwId = ref.watch(departureRunwayIdProvider);
  if (airport == null || rwId.isEmpty) return null;
  try {
    return airport.runways.firstWhere((r) => r.id == rwId);
  } catch (_) {
    return null;
  }
});

final arrivalRunwayProvider = Provider<Runway?>((ref) {
  final airport = ref.watch(arrAirportProvider);
  final rwId = ref.watch(arrivalRunwayIdProvider);
  if (airport == null || rwId.isEmpty) return null;
  try {
    return airport.runways.firstWhere((r) => r.id == rwId);
  } catch (_) {
    return null;
  }
});

/// Alternate distance as flown: the plan's alternate route distance when
/// imported, else great circle + airway/terminal allowances.
final alternateDistanceProvider = Provider<double>((ref) {
  final planned = ref.watch(alternateRouteDistanceProvider);
  if (planned != null && planned > 0) return planned;
  final arr = ref.watch(arrAirportProvider);
  final alt = ref.watch(altAirportProvider);
  if (arr == null || alt == null) return 0.0;
  return ConcordeLogic.estimatedRouteDistanceNm(
    ConcordeLogic.greatCircleNM(arr.lat, arr.lon, alt.lat, alt.lon),
  );
});

final alternateStatusProvider = Provider<AlternateStatus>((ref) {
  return ConcordeLogic.alternateStatus(
    alternateIcao: ref.watch(alternateIcaoProvider),
    arrivalIcao: ref.watch(arrivalIcaoProvider),
    alternateResolved: ref.watch(altAirportProvider) != null,
    alternateNm: ref.watch(alternateDistanceProvider),
  );
});

final missionProfileProvider = Provider<CruiseMissionProfile>((ref) {
  final distance = ref.watch(plannedDistanceProvider);
  final cruiseFL = ref.watch(cruiseFLProvider);
  return ConcordeLogic.buildCruiseMissionProfile(distance, cruiseFL);
});

final fuelBreakdownProvider = Provider<BlockFuelBreakdown>((ref) {
  final mission = ref.watch(missionProfileProvider);
  return ConcordeLogic.blockFuelKg(
    BlockFuelInputs(
      tripKg: mission.tripKg,
      taxiKg: ref.watch(taxiFuelProvider),
      contingencyPct: ref.watch(contingencyPctProvider),
      finalReserveKg: ref.watch(finalReserveFuelProvider),
      alternateNm: ref.watch(alternateDistanceProvider),
    ),
  );
});

final paxWeightProvider = Provider<double>((ref) {
  final count = ref.watch(paxCountProvider);
  return count * ConcordeConstants.weights.paxMassKg;
});

final weightsProvider = Provider<WeightSummary>((ref) {
  final fuel = ref.watch(fuelBreakdownProvider);
  return ConcordeLogic.computeWeights(
    paxKg: ref.watch(paxWeightProvider),
    plannedFuelKg: fuel.blockKg + ref.watch(extraFuelProvider),
    taxiKg: fuel.taxiKg,
    tripKg: ref.watch(missionProfileProvider).tripKg,
  );
});

final fuelEnduranceProvider = Provider<FuelEndurance>((ref) {
  return ConcordeLogic.computeEndurance(
    fuel: ref.watch(fuelBreakdownProvider),
    fuelOnBoardKg: ref.watch(weightsProvider).fuelOnBoard,
    eteH: ref.watch(missionProfileProvider).totalTimeH,
  );
});

class UseReheatTakeoffNotifier extends Notifier<bool> {
  @override
  bool build() => true;
  void set(bool val) => state = val;
}

final useReheatTakeoffProvider =
    NotifierProvider<UseReheatTakeoffNotifier, bool>(
      UseReheatTakeoffNotifier.new,
    );

class RunwayConditionModeNotifier extends Notifier<RunwayConditionMode> {
  @override
  RunwayConditionMode build() => RunwayConditionMode.auto;
  void set(RunwayConditionMode val) => state = val;
}

final departureRunwayConditionProvider =
    NotifierProvider<RunwayConditionModeNotifier, RunwayConditionMode>(
      RunwayConditionModeNotifier.new,
    );

final arrivalRunwayConditionProvider =
    NotifierProvider<RunwayConditionModeNotifier, RunwayConditionMode>(
      RunwayConditionModeNotifier.new,
    );

/// Runway environment (pressure, temperature, wind, surface) for the
/// selected departure runway, or null when no runway is selected.
final departureEnvProvider = Provider<RunwayEnvironmentInputs?>((ref) {
  final runway = ref.watch(departureRunwayProvider);
  if (runway == null) return null;
  return ConcordeLogic.runwayEnvFromMetar(
    metar: ref.watch(departureMetarFutureProvider).value ?? '',
    runwayHeadingDeg: runway.heading.toDouble(),
    runwayElevFt: runway.elevationFt,
    conditionMode: ref.watch(departureRunwayConditionProvider),
  );
});

final arrivalEnvProvider = Provider<RunwayEnvironmentInputs?>((ref) {
  final runway = ref.watch(arrivalRunwayProvider);
  if (runway == null) return null;
  return ConcordeLogic.runwayEnvFromMetar(
    metar: ref.watch(arrivalMetarFutureProvider).value ?? '',
    runwayHeadingDeg: runway.heading.toDouble(),
    runwayElevFt: runway.elevationFt,
    conditionMode: ref.watch(arrivalRunwayConditionProvider),
  );
});

final takeoffSpeedsProvider = Provider<TakeoffSpeeds>((ref) {
  return ConcordeLogic.computeTakeoffSpeeds(
    ref.watch(weightsProvider).tow,
    condition:
        ref.watch(departureEnvProvider)?.condition ?? RunwayCondition.dry,
  );
});

final landingSpeedsProvider = Provider<LandingSpeeds>((ref) {
  final env = ref.watch(arrivalEnvProvider);
  return ConcordeLogic.computeLandingSpeeds(
    ref.watch(weightsProvider).lw,
    headwindKt: env?.headwindKt,
    gustIncrementKt: env?.gustIncrementKt ?? 0,
  );
});

RunwayFeasibility? _takeoffFeasibility(Ref ref, {required bool useReheat}) {
  final runway = ref.watch(departureRunwayProvider);
  if (runway == null) return null;
  return ConcordeLogic.takeoffFeasibleM(
    runway.lengthM,
    ref.watch(weightsProvider).tow,
    env: ref.watch(departureEnvProvider),
    useReheat: useReheat,
    runwayWidthFt: runway.widthFt,
  );
}

final takeoffFeasibilityProvider = Provider<RunwayFeasibility?>(
  (ref) =>
      _takeoffFeasibility(ref, useReheat: ref.watch(useReheatTakeoffProvider)),
);

/// Same takeoff feasibility check, but always forced to no-reheat -- lets
/// the UI tell the pilot when reheat isn't actually required for this
/// takeoff, regardless of [useReheatTakeoffProvider]'s own setting.
final takeoffFeasibilityNoReheatProvider = Provider<RunwayFeasibility?>(
  (ref) => _takeoffFeasibility(ref, useReheat: false),
);

final landingFeasibilityProvider = Provider<RunwayFeasibility?>((ref) {
  final runway = ref.watch(arrivalRunwayProvider);
  if (runway == null) return null;
  return ConcordeLogic.landingFeasibleM(
    runway.lengthM,
    ref.watch(weightsProvider).lw,
    env: ref.watch(arrivalEnvProvider),
    runwayWidthFt: runway.widthFt,
  );
});

/// Rolls every planner check into a single GO / NO-GO for the banner.
final dispatchSummaryProvider = Provider<DispatchSummary>((ref) {
  final noGo = <String>[];
  final cautions = <String>[];
  final w = ref.watch(weightsProvider);
  final limits = ConcordeConstants.weights;
  final runway = ConcordeConstants.runway;

  if (w.overCapacity) {
    noGo.add(
      'Fuel required exceeds tank capacity by '
      '${(w.plannedFuel - w.fuelOnBoard).round()} kg',
    );
  } else if (!ref.watch(fuelEnduranceProvider).sufficient) {
    noGo.add('Fuel endurance below ETE + reserves');
  }
  if (w.tow > limits.mtowKg) noGo.add('Takeoff weight above MTOW');
  if (w.lw > limits.mlwKg) {
    noGo.add('Landing weight above MLW (${w.lw.round()} kg)');
  }

  void runwayChecks(String leg, RunwayFeasibility? f, bool hasAirport) {
    if (!hasAirport) {
      noGo.add('$leg airport not found');
      return;
    }
    if (f == null) {
      noGo.add('$leg runway not selected');
      return;
    }
    if (f.runwayLengthM < f.requiredLengthMEst) {
      noGo.add(
        '$leg runway ${(f.requiredLengthMEst - f.runwayLengthM).round()} m too short',
      );
    }
    if (!f.crosswindOk) {
      noGo.add('$leg crosswind above ${runway.maxCrosswindKt.round()} kt');
    }
    if (!f.tailwindOk) {
      noGo.add('$leg tailwind above ${runway.maxTailwindKt.round()} kt');
    }
    if (!f.altitudeOk) noGo.add('$leg airfield outside altitude limits');
    if (!f.widthOk) cautions.add('$leg runway narrower than 150 ft');
    if (!f.windDataAvailable) cautions.add('$leg wind unknown (no METAR)');
    if (f.condition != RunwayCondition.dry) {
      cautions.add('$leg runway ${f.condition.name}');
    }
  }

  runwayChecks(
    'Departure',
    ref.watch(takeoffFeasibilityProvider),
    ref.watch(depAirportProvider) != null,
  );
  if (!ref.watch(useReheatTakeoffProvider) && w.tow >= 155000) {
    noGo.add('No-reheat takeoff above 155 t');
  }
  runwayChecks(
    'Arrival',
    ref.watch(landingFeasibilityProvider),
    ref.watch(arrAirportProvider) != null,
  );

  switch (ref.watch(alternateStatusProvider)) {
    case AlternateStatus.ok:
      break;
    case AlternateStatus.missing:
      cautions.add('No alternate');
    case AlternateStatus.sameAsArrival:
      cautions.add('Alternate same as arrival');
    case AlternateStatus.unknownAirport:
      cautions.add('Alternate airport not found');
    case AlternateStatus.tooFar:
      cautions.add('Alternate beyond 500 nm');
  }
  final mission = ref.watch(missionProfileProvider);
  if (mission.flCappedForDistance) {
    cautions.add('Planned at FL${mission.targetCruiseFl} (sector too short)');
  }
  return DispatchSummary(noGo: noGo, cautions: cautions);
});

class ChecklistNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  /// Clears all checked items — call this when a new flight plan (e.g. a
  /// fresh SimBrief import) is loaded, so stale progress from the previous
  /// flight doesn't carry over.
  void resetAll() => state = {};

  void toggle(String itemId) {
    state = {...state, itemId: !(state[itemId] ?? false)};
  }

  void resetPhase(List<String> itemIds) {
    final newState = Map<String, bool>.from(state);
    for (final id in itemIds) {
      newState[id] = false;
    }
    state = newState;
  }
}

final checklistProvider =
    NotifierProvider<ChecklistNotifier, Map<String, bool>>(
      ChecklistNotifier.new,
    );

// --- Theme Mode State ---
class ThemeModeNotifier extends Notifier<ThemeMode> {
  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _loadPrefs();
    return ThemeMode.light;
  }

  void _loadPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs?.getString('theme_mode');
    if (saved != null) {
      if (saved == 'dark') {
        state = ThemeMode.dark;
      } else if (saved == 'light') {
        state = ThemeMode.light;
      } else if (saved == 'system') {
        state = ThemeMode.system;
      }
    }
  }

  void set(ThemeMode mode) async {
    state = mode;
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs?.setString(
      'theme_mode',
      mode == ThemeMode.dark
          ? 'dark'
          : (mode == ThemeMode.light ? 'light' : 'system'),
    );
  }

  void toggle() {
    if (state == ThemeMode.dark) {
      set(ThemeMode.light);
    } else {
      set(ThemeMode.dark);
    }
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
