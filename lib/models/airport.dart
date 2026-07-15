class Airport {
  final String icao;
  final String name;
  final double lat;
  final double lon;
  final double? elevationFt;
  final List<Runway> runways;

  Airport({
    required this.icao,
    required this.name,
    required this.lat,
    required this.lon,
    this.elevationFt,
    List<Runway>? runways,
  }) : runways = runways ?? [];
}

class Runway {
  final String id;
  final int heading;
  final double lengthM;
  final double? elevationFt;

  Runway({
    required this.id,
    required this.heading,
    required this.lengthM,
    this.elevationFt,
  });
}
