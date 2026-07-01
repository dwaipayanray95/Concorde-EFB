class TelemetryModel {
  final int timestamp;
  
  // Basic parameters
  final double altitude;
  final double ias;
  final double tas;
  final double gs;
  final double heading;
  final double vs;
  final double pitch;
  final double roll;
  final double latitude;
  final double longitude;
  final double gForce;
  final double gearPosition;
  final int flapsPosition;
  final String zuluTime;

  // Concorde parameters
  final double mach;
  final double tat;
  final double cgPct;
  final double cgAftLimit;
  final double cgFwdLimit;
  final double fuelBurnTotal;
  final List<bool> reheatActive;
  final double snootAngle;
  
  // Fuel Tanks fill percentages
  final double fuelLeftTank;
  final double fuelRightTank;
  final double fuelCenterTank;
  final double fuelTrimForward;
  final double fuelTrimAft;

  // Landing touchdown events
  final bool isLanding;
  final double touchdownVS;
  final double touchdownPitch;
  final double touchdownGForce;

  TelemetryModel({
    required this.timestamp,
    required this.altitude,
    required this.ias,
    required this.tas,
    required this.gs,
    required this.heading,
    required this.vs,
    required this.pitch,
    required this.roll,
    required this.latitude,
    required this.longitude,
    required this.gForce,
    required this.gearPosition,
    required this.flapsPosition,
    required this.zuluTime,
    required this.mach,
    required this.tat,
    required this.cgPct,
    required this.cgAftLimit,
    required this.cgFwdLimit,
    required this.fuelBurnTotal,
    required this.reheatActive,
    required this.snootAngle,
    required this.fuelLeftTank,
    required this.fuelRightTank,
    required this.fuelCenterTank,
    required this.fuelTrimForward,
    required this.fuelTrimAft,
    required this.isLanding,
    required this.touchdownVS,
    required this.touchdownPitch,
    required this.touchdownGForce,
  });

  factory TelemetryModel.fromJson(Map<String, dynamic> json) {
    final basic = json['basic'] ?? {};
    final concorde = json['concorde'] ?? {};
    final fuelTanks = concorde['fuelTanks'] ?? {};
    final events = json['events'] ?? {};

    return TelemetryModel(
      timestamp: json['timestamp'] ?? 0,
      altitude: (basic['altitude'] ?? 0.0).toDouble(),
      ias: (basic['ias'] ?? 0.0).toDouble(),
      tas: (basic['tas'] ?? 0.0).toDouble(),
      gs: (basic['gs'] ?? 0.0).toDouble(),
      heading: (basic['heading'] ?? 0.0).toDouble(),
      vs: (basic['vs'] ?? 0.0).toDouble(),
      pitch: (basic['pitch'] ?? 0.0).toDouble(),
      roll: (basic['roll'] ?? 0.0).toDouble(),
      latitude: (basic['latitude'] ?? 0.0).toDouble(),
      longitude: (basic['longitude'] ?? 0.0).toDouble(),
      gForce: (basic['gForce'] ?? 1.0).toDouble(),
      gearPosition: (basic['gearPosition'] ?? 0.0).toDouble(),
      flapsPosition: (basic['flapsPosition'] ?? 0).toInt(),
      zuluTime: basic['zuluTime'] ?? "00:00:00",
      mach: (concorde['mach'] ?? 0.0).toDouble(),
      tat: (concorde['tat'] ?? 0.0).toDouble(),
      cgPct: (concorde['cgPct'] ?? 0.0).toDouble(),
      cgAftLimit: (concorde['cgAftLimit'] ?? 59.0).toDouble(),
      cgFwdLimit: (concorde['cgFwdLimit'] ?? 52.0).toDouble(),
      fuelBurnTotal: (concorde['fuelBurnTotal'] ?? 0.0).toDouble(),
      reheatActive: List<bool>.from(concorde['reheatActive'] ?? [false, false, false, false]),
      snootAngle: (concorde['snootAngle'] ?? 0.0).toDouble(),
      fuelLeftTank: (fuelTanks['left'] ?? 0.0).toDouble(),
      fuelRightTank: (fuelTanks['right'] ?? 0.0).toDouble(),
      fuelCenterTank: (fuelTanks['center'] ?? 0.0).toDouble(),
      fuelTrimForward: (fuelTanks['trimForward'] ?? 0.0).toDouble(),
      fuelTrimAft: (fuelTanks['trimAft'] ?? 0.0).toDouble(),
      isLanding: events['isLanding'] ?? false,
      touchdownVS: (events['touchdownVS'] ?? 0.0).toDouble(),
      touchdownPitch: (events['touchdownPitch'] ?? 0.0).toDouble(),
      touchdownGForce: (events['touchdownGForce'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'basic': {
        'altitude': altitude,
        'ias': ias,
        'tas': tas,
        'gs': gs,
        'heading': heading,
        'vs': vs,
        'pitch': pitch,
        'roll': roll,
        'latitude': latitude,
        'longitude': longitude,
        'gForce': gForce,
        'gearPosition': gearPosition,
        'flapsPosition': flapsPosition,
        'zuluTime': zuluTime,
      },
      'concorde': {
        'mach': mach,
        'tat': tat,
        'cgPct': cgPct,
        'cgAftLimit': cgAftLimit,
        'cgFwdLimit': cgFwdLimit,
        'fuelBurnTotal': fuelBurnTotal,
        'reheatActive': reheatActive,
        'snootAngle': snootAngle,
        'fuelTanks': {
          'left': fuelLeftTank,
          'right': fuelRightTank,
          'center': fuelCenterTank,
          'trimForward': fuelTrimForward,
          'trimAft': fuelTrimAft,
        }
      },
      'events': {
        'isLanding': isLanding,
        'touchdownVS': touchdownVS,
        'touchdownPitch': touchdownPitch,
        'touchdownGForce': touchdownGForce,
      }
    };
  }
}
