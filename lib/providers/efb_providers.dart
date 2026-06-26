import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/airport_database_service.dart';
import '../core/concorde_logic.dart';
import '../models/concorde_models.dart';
import '../models/airport.dart';
import '../core/concorde_constants.dart';
import '../services/metar_service.dart';

final airportDbProvider = FutureProvider<AirportDatabaseService>((ref) async {
  final service = AirportDatabaseService();
  await service.initialize();
  return service;
});

// --- Flight Plan State ---
class DepartureIcaoNotifier extends Notifier<String> {
  @override
  String build() => 'EGLL';
  void set(String val) => state = val.toUpperCase();
}
final departureIcaoProvider = NotifierProvider<DepartureIcaoNotifier, String>(DepartureIcaoNotifier.new);

class ArrivalIcaoNotifier extends Notifier<String> {
  @override
  String build() => 'KJFK';
  void set(String val) => state = val.toUpperCase();
}
final arrivalIcaoProvider = NotifierProvider<ArrivalIcaoNotifier, String>(ArrivalIcaoNotifier.new);

class AlternateIcaoNotifier extends Notifier<String> {
  @override
  String build() => 'KBOS';
  void set(String val) => state = val.toUpperCase();
}
final alternateIcaoProvider = NotifierProvider<AlternateIcaoNotifier, String>(AlternateIcaoNotifier.new);

class PlannedDistanceNotifier extends Notifier<double> {
  @override
  double build() => 3000.0;
  void set(double val) => state = val;
}
final plannedDistanceProvider = NotifierProvider<PlannedDistanceNotifier, double>(PlannedDistanceNotifier.new);

// --- SimBrief State ---
class SimbriefUserNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}
final simbriefUserProvider = NotifierProvider<SimbriefUserNotifier, String>(SimbriefUserNotifier.new);

class CallSignNotifier extends Notifier<String> {
  @override
  String build() => '--';
  void set(String val) => state = val;
}
final callSignProvider = NotifierProvider<CallSignNotifier, String>(CallSignNotifier.new);

class RegistrationNotifier extends Notifier<String> {
  @override
  String build() => '--';
  void set(String val) => state = val;
}
final registrationProvider = NotifierProvider<RegistrationNotifier, String>(RegistrationNotifier.new);

class SimbriefLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}
final simbriefLoadingProvider = NotifierProvider<SimbriefLoadingNotifier, bool>(SimbriefLoadingNotifier.new);

class SimbriefRouteNotifier extends Notifier<String> {
  @override
  String build() => '--';
  void set(String val) => state = val;
}
final simbriefRouteProvider = NotifierProvider<SimbriefRouteNotifier, String>(SimbriefRouteNotifier.new);

class SimbriefLoadedNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool val) => state = val;
}
final simbriefLoadedProvider = NotifierProvider<SimbriefLoadedNotifier, bool>(SimbriefLoadedNotifier.new);

// --- Runways State ---
class DepartureRunwayIdNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}
final departureRunwayIdProvider = NotifierProvider<DepartureRunwayIdNotifier, String>(DepartureRunwayIdNotifier.new);

class ArrivalRunwayIdNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String val) => state = val;
}
final arrivalRunwayIdProvider = NotifierProvider<ArrivalRunwayIdNotifier, String>(ArrivalRunwayIdNotifier.new);
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

// Better approach: Make METARs FutureProviders based on ICAO
final departureMetarFutureProvider = FutureProvider<String>((ref) async {
  final icao = ref.watch(departureIcaoProvider);
  if (icao.isEmpty) return '';
  final metar = await MetarService().fetchMetar(icao);
  return metar ?? '';
});

final arrivalMetarFutureProvider = FutureProvider<String>((ref) async {
  final icao = ref.watch(arrivalIcaoProvider);
  if (icao.isEmpty) return '';
  final metar = await MetarService().fetchMetar(icao);
  return metar ?? '';
});

final flightDirectionProvider = Provider<String?>((ref) {
  final dep = ref.watch(depAirportProvider);
  final arr = ref.watch(arrAirportProvider);
  if (dep == null || arr == null) return null;
  return ConcordeLogic.inferDirectionEW(dep.lat, dep.lon, arr.lat, arr.lon);
});

// --- Cruise & Payload State ---
class CruiseFLNotifier extends Notifier<double> {
  @override
  double build() => 590.0;
  void set(double val, String? direction) {
    state = ConcordeLogic.snapToNonRvsm(val, direction);
  }
}
final cruiseFLProvider = NotifierProvider<CruiseFLNotifier, double>(CruiseFLNotifier.new);

class TaxiFuelNotifier extends Notifier<double> {
  @override
  double build() => 2500.0;
  void set(double val) => state = val;
}
final taxiFuelProvider = NotifierProvider<TaxiFuelNotifier, double>(TaxiFuelNotifier.new);

class ContingencyPctNotifier extends Notifier<double> {
  @override
  double build() => 5.0;
  void set(double val) => state = val;
}
final contingencyPctProvider = NotifierProvider<ContingencyPctNotifier, double>(ContingencyPctNotifier.new);

class FinalReserveFuelNotifier extends Notifier<double> {
  @override
  double build() => 3600.0;
  void set(double val) => state = val;
}
final finalReserveFuelProvider = NotifierProvider<FinalReserveFuelNotifier, double>(FinalReserveFuelNotifier.new);

class TrimTankFuelNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void set(double val) => state = val;
}
final trimTankFuelProvider = NotifierProvider<TrimTankFuelNotifier, double>(TrimTankFuelNotifier.new);

class ExtraFuelNotifier extends Notifier<double> {
  @override
  double build() => 0.0;
  void set(double val) => state = val;
}
final extraFuelProvider = NotifierProvider<ExtraFuelNotifier, double>(ExtraFuelNotifier.new);

class PaxCountNotifier extends Notifier<int> {
  @override
  int build() => 100;
  void set(int val) => state = val;
}
final paxCountProvider = NotifierProvider<PaxCountNotifier, int>(PaxCountNotifier.new);

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

final alternateDistanceProvider = Provider<double>((ref) {
  final arr = ref.watch(arrAirportProvider);
  final alt = ref.watch(altAirportProvider);
  if (arr == null || alt == null) return 0.0;
  return ConcordeLogic.greatCircleNM(arr.lat, arr.lon, alt.lat, alt.lon);
});

final missionProfileProvider = Provider<CruiseMissionProfile>((ref) {
  final distance = ref.watch(plannedDistanceProvider);
  final cruiseFL = ref.watch(cruiseFLProvider);
  return ConcordeLogic.buildCruiseMissionProfile(distance, cruiseFL);
});

final fuelBreakdownProvider = Provider<BlockFuelBreakdown>((ref) {
  final mission = ref.watch(missionProfileProvider);
  final taxi = ref.watch(taxiFuelProvider);
  final contingency = ref.watch(contingencyPctProvider);
  final reserve = ref.watch(finalReserveFuelProvider);
  final altDist = ref.watch(alternateDistanceProvider);
  
  return ConcordeLogic.blockFuelKg(BlockFuelInputs(
    tripKg: mission.tripKg,
    taxiKg: taxi,
    contingencyPct: contingency,
    finalReserveKg: reserve,
    alternateNm: altDist,
  ));
});

final paxWeightProvider = Provider<double>((ref) {
  final count = ref.watch(paxCountProvider);
  return count * ConcordeConstants.weights.paxMassKg;
});

final weightsProvider = Provider<Map<String, double>>((ref) {
  final fuel = ref.watch(fuelBreakdownProvider);
  final trim = ref.watch(trimTankFuelProvider);
  final extra = ref.watch(extraFuelProvider);
  final totalFuel = fuel.blockKg + trim + extra;
  final paxWeight = ref.watch(paxWeightProvider);
  
  final tow = ConcordeConstants.weights.oewKg + paxWeight + totalFuel;
  final mission = ref.watch(missionProfileProvider);
  final lw = tow - mission.tripKg;
  
  return {
    'TOW': tow,
    'LW': lw,
    'FUEL': totalFuel,
    'PAX': paxWeight,
  };
});

final takeoffSpeedsProvider = Provider<Map<String, double>>((ref) {
  final weights = ref.watch(weightsProvider);
  return ConcordeLogic.computeTakeoffSpeeds(weights['TOW']!);
});

final landingSpeedsProvider = Provider<Map<String, double>>((ref) {
  final weights = ref.watch(weightsProvider);
  return ConcordeLogic.computeLandingSpeeds(weights['LW']!);
});

final takeoffFeasibilityProvider = Provider<RunwayFeasibility?>((ref) {
  final runway = ref.watch(departureRunwayProvider);
  final weights = ref.watch(weightsProvider);
  if (runway == null) return null;
  
  return ConcordeLogic.takeoffFeasibleM(runway.lengthM, weights['TOW']!);
});

final landingFeasibilityProvider = Provider<RunwayFeasibility?>((ref) {
  final runway = ref.watch(arrivalRunwayProvider);
  final weights = ref.watch(weightsProvider);
  if (runway == null) return null;
  
  return ConcordeLogic.landingFeasibleM(runway.lengthM, weights['LW']!);
});

class ChecklistNotifier extends Notifier<Map<String, bool>> {
  @override
  Map<String, bool> build() => {};

  void toggle(String itemId) {
    state = {
      ...state,
      itemId: !(state[itemId] ?? false),
    };
  }

  void resetPhase(List<String> itemIds) {
    final newState = Map<String, bool>.from(state);
    for (final id in itemIds) {
      newState[id] = false;
    }
    state = newState;
  }
}
final checklistProvider = NotifierProvider<ChecklistNotifier, Map<String, bool>>(ChecklistNotifier.new);
