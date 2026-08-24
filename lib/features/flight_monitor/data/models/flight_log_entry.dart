/// One completed flight, auto-logged the instant a landing is detected.
/// Unlike the old frame-by-frame recorder, this stores a single summary
/// row per flight -- no timeline/frames to play back.
class FlightLogEntry {
  final String id;
  final String date;
  final int durationSeconds;
  final String departureIcao;
  final String arrivalIcao;
  final double distanceNm;
  final double? maxMach;
  final double? maxAltitudeFt;
  final double? fuelBurnedKg;
  final int reheatSeconds;
  final double? touchdownVS;
  final double? touchdownPitch;
  final double? touchdownGForce;

  FlightLogEntry({
    required this.id,
    required this.date,
    required this.durationSeconds,
    this.departureIcao = '',
    this.arrivalIcao = '',
    this.distanceNm = 0,
    this.maxMach,
    this.maxAltitudeFt,
    this.fuelBurnedKg,
    this.reheatSeconds = 0,
    this.touchdownVS,
    this.touchdownPitch,
    this.touchdownGForce,
  });

  factory FlightLogEntry.fromJson(Map<String, dynamic> json) {
    return FlightLogEntry(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      durationSeconds: json['durationSeconds'] ?? 0,
      departureIcao: json['departureIcao'] ?? '',
      arrivalIcao: json['arrivalIcao'] ?? '',
      distanceNm: (json['distanceNm'] ?? 0).toDouble(),
      maxMach: json['maxMach']?.toDouble(),
      maxAltitudeFt: json['maxAltitudeFt']?.toDouble(),
      fuelBurnedKg: json['fuelBurnedKg']?.toDouble(),
      reheatSeconds: json['reheatSeconds'] ?? 0,
      touchdownVS: json['touchdownVS']?.toDouble(),
      touchdownPitch: json['touchdownPitch']?.toDouble(),
      touchdownGForce: json['touchdownGForce']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'durationSeconds': durationSeconds,
      'departureIcao': departureIcao,
      'arrivalIcao': arrivalIcao,
      'distanceNm': distanceNm,
      'maxMach': maxMach,
      'maxAltitudeFt': maxAltitudeFt,
      'fuelBurnedKg': fuelBurnedKg,
      'reheatSeconds': reheatSeconds,
      'touchdownVS': touchdownVS,
      'touchdownPitch': touchdownPitch,
      'touchdownGForce': touchdownGForce,
    };
  }
}
