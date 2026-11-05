import '../domain/landing_rating.dart';

DateTime? _dt(Object? v) =>
    v == null ? null : DateTime.parse(v as String).toUtc();
double? _d(Object? v) => (v as num?)?.toDouble();

/// One logged flight (immutable). Written by `FlightTracker`, stored as JSON.
class FlightLog {
  static const schemaVersion = 1;

  final String id;
  final DateTime updatedAt;
  final String notes;

  final String callSign, registration, plannedDep, plannedArr, alternate;
  final String planSource;
  final String? actualDep, actualArr;

  final DateTime blockOut;
  final DateTime? takeoff, touchdown, blockIn;

  final double plannedTimeH, plannedTripKg, cruiseFl;
  final double? fuelBlockOutKg, fuelTakeoffKg, fuelLandingKg, fuelBlockInKg;
  final double finalReserveKg, zfwKg;

  final double maxMach, maxAltFt, supersonicSec, reheatSec, distanceNm;

  /// Rate of descent at touchdown (positive = descending).
  final double? touchdownFpm, touchdownG, touchdownPitch, touchdownIas;
  final int bounces;

  /// Alert text -> times it newly appeared during the flight.
  final Map<String, int> alerts;

  /// `[epochSec, lat, lon, altFt, gsKt, iasKt, vsFpm, mach, fuelKg, cgPct]`
  /// every 5 s (older logs only have the first five).
  final List<List<num>> track;

  /// Measured performance vs what the planner predicted, for validating
  /// the runway / fuel models from real sim flights. Free-form JSON:
  /// `takeoff` / `landing` blocks (see `FlightTracker`). Empty on old logs.
  final Map<String, dynamic> perf;

  const FlightLog({
    required this.id,
    required this.updatedAt,
    this.notes = '',
    this.callSign = '',
    this.registration = '',
    this.plannedDep = '',
    this.plannedArr = '',
    this.alternate = '',
    this.planSource = '',
    this.actualDep,
    this.actualArr,
    required this.blockOut,
    this.takeoff,
    this.touchdown,
    this.blockIn,
    this.plannedTimeH = 0,
    this.plannedTripKg = 0,
    this.cruiseFl = 0,
    this.fuelBlockOutKg,
    this.fuelTakeoffKg,
    this.fuelLandingKg,
    this.fuelBlockInKg,
    this.finalReserveKg = 0,
    this.zfwKg = 0,
    this.maxMach = 0,
    this.maxAltFt = 0,
    this.supersonicSec = 0,
    this.reheatSec = 0,
    this.distanceNm = 0,
    this.touchdownFpm,
    this.touchdownG,
    this.touchdownPitch,
    this.touchdownIas,
    this.bounces = 0,
    this.alerts = const {},
    this.track = const [],
    this.perf = const {},
  });

  Map<String, dynamic>? get takeoffPerf =>
      (perf['takeoff'] as Map?)?.cast<String, dynamic>();
  Map<String, dynamic>? get landingPerf =>
      (perf['landing'] as Map?)?.cast<String, dynamic>();

  Duration? get blockTime => blockIn?.difference(blockOut);
  Duration? get flightTime => (takeoff != null && touchdown != null)
      ? touchdown!.difference(takeoff!)
      : null;

  /// Fuel used block-out to block-in (or to landing if still rolling out).
  double? get fuelBurnedKg {
    final end = fuelBlockInKg ?? fuelLandingKg;
    return (fuelBlockOutKg != null && end != null)
        ? fuelBlockOutKg! - end
        : null;
  }

  double? get towKg => fuelTakeoffKg == null ? null : zfwKg + fuelTakeoffKg!;
  double? get lwKg => fuelLandingKg == null ? null : zfwKg + fuelLandingKg!;

  LandingRating? get landingRating =>
      touchdownFpm == null ? null : rateLanding(touchdownFpm!, touchdownG ?? 1);

  FlightLog copyWith({String? notes, DateTime? updatedAt}) =>
      FlightLog.fromJson({
        ...toJson(),
        'notes': notes ?? this.notes,
        'updatedAt': (updatedAt ?? this.updatedAt).toIso8601String(),
      });

  Map<String, dynamic> toJson() => {
    'v': schemaVersion,
    'id': id,
    'updatedAt': updatedAt.toIso8601String(),
    'notes': notes,
    'callSign': callSign,
    'registration': registration,
    'plannedDep': plannedDep,
    'plannedArr': plannedArr,
    'alternate': alternate,
    'planSource': planSource,
    'actualDep': actualDep,
    'actualArr': actualArr,
    'blockOut': blockOut.toIso8601String(),
    'takeoff': takeoff?.toIso8601String(),
    'touchdown': touchdown?.toIso8601String(),
    'blockIn': blockIn?.toIso8601String(),
    'plannedTimeH': plannedTimeH,
    'plannedTripKg': plannedTripKg,
    'cruiseFl': cruiseFl,
    'fuelBlockOutKg': fuelBlockOutKg,
    'fuelTakeoffKg': fuelTakeoffKg,
    'fuelLandingKg': fuelLandingKg,
    'fuelBlockInKg': fuelBlockInKg,
    'finalReserveKg': finalReserveKg,
    'zfwKg': zfwKg,
    'maxMach': maxMach,
    'maxAltFt': maxAltFt,
    'supersonicSec': supersonicSec,
    'reheatSec': reheatSec,
    'distanceNm': distanceNm,
    'touchdownFpm': touchdownFpm,
    'touchdownG': touchdownG,
    'touchdownPitch': touchdownPitch,
    'touchdownIas': touchdownIas,
    'bounces': bounces,
    'alerts': alerts,
    'track': track,
    'perf': perf,
  };

  factory FlightLog.fromJson(Map<String, dynamic> j) => FlightLog(
    id: j['id'] as String,
    updatedAt:
        _dt(j['updatedAt']) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    notes: j['notes'] as String? ?? '',
    callSign: j['callSign'] as String? ?? '',
    registration: j['registration'] as String? ?? '',
    plannedDep: j['plannedDep'] as String? ?? '',
    plannedArr: j['plannedArr'] as String? ?? '',
    alternate: j['alternate'] as String? ?? '',
    planSource: j['planSource'] as String? ?? '',
    actualDep: j['actualDep'] as String?,
    actualArr: j['actualArr'] as String?,
    blockOut: _dt(j['blockOut'])!,
    takeoff: _dt(j['takeoff']),
    touchdown: _dt(j['touchdown']),
    blockIn: _dt(j['blockIn']),
    plannedTimeH: _d(j['plannedTimeH']) ?? 0,
    plannedTripKg: _d(j['plannedTripKg']) ?? 0,
    cruiseFl: _d(j['cruiseFl']) ?? 0,
    fuelBlockOutKg: _d(j['fuelBlockOutKg']),
    fuelTakeoffKg: _d(j['fuelTakeoffKg']),
    fuelLandingKg: _d(j['fuelLandingKg']),
    fuelBlockInKg: _d(j['fuelBlockInKg']),
    finalReserveKg: _d(j['finalReserveKg']) ?? 0,
    zfwKg: _d(j['zfwKg']) ?? 0,
    maxMach: _d(j['maxMach']) ?? 0,
    maxAltFt: _d(j['maxAltFt']) ?? 0,
    supersonicSec: _d(j['supersonicSec']) ?? 0,
    reheatSec: _d(j['reheatSec']) ?? 0,
    distanceNm: _d(j['distanceNm']) ?? 0,
    touchdownFpm: _d(j['touchdownFpm']),
    touchdownG: _d(j['touchdownG']),
    touchdownPitch: _d(j['touchdownPitch']),
    touchdownIas: _d(j['touchdownIas']),
    bounces: (j['bounces'] as num?)?.toInt() ?? 0,
    alerts: {
      for (final e in ((j['alerts'] as Map?) ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    track: [
      for (final p in (j['track'] as List? ?? const []))
        [for (final n in (p as List)) n as num],
    ],
    perf: ((j['perf'] as Map?) ?? const {}).cast<String, dynamic>(),
  );
}
