import 'package:http/http.dart' as http;
import 'package:csv/csv.dart';
import '../models/airport.dart';

class AirportDatabaseService {
  static const String airportsUrl = 'https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/airports.csv';
  static const String runwaysUrl = 'https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/runways.csv';
  static const String navaidsUrl = 'https://raw.githubusercontent.com/davidmegginson/ourairports-data/master/navaids.csv';

  Map<String, Airport> airports = {};
  Map<String, List<Navaid>> navaids = {};

  Future<void> initialize() async {
    try {
      // Use a slightly larger timeout for these large files
      final responses = await Future.wait([
        http.get(Uri.parse(airportsUrl)).timeout(const Duration(seconds: 30)),
        http.get(Uri.parse(runwaysUrl)).timeout(const Duration(seconds: 30)),
        http.get(Uri.parse(navaidsUrl)).timeout(const Duration(seconds: 30)),
      ]);

      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Failed to fetch data from OurAirports (Status: ${responses.map((r) => r.statusCode).join(", ")})');
      }

      final airportsCsv = responses[0].body;
      final runwaysCsv = responses[1].body;
      final navaidsCsv = responses[2].body;

      _buildAirportsDb(airportsCsv, runwaysCsv);
      _buildNavaidsDb(navaidsCsv);
    } catch (e) {
      rethrow;
    }
  }

  void _buildAirportsDb(String airportsCsv, String runwaysCsv) {
    const decoder = CsvDecoder();
    final airportsData = decoder.convert(airportsCsv);
    if (airportsData.isEmpty) return;

    final airHeader = airportsData[0].map((e) => e.toString()).toList();
    final identIdx = airHeader.indexOf('ident');
    final nameIdx = airHeader.indexOf('name');
    final latIdx = airHeader.indexOf('latitude_deg');
    final lonIdx = airHeader.indexOf('longitude_deg');
    final elevIdx = airHeader.indexOf('elevation_ft');

    // Optimization: Build map first
    for (var i = 1; i < airportsData.length; i++) {
      final row = airportsData[i];
      if (row.length <= identIdx) continue;
      
      final icao = row[identIdx].toString().trim().toUpperCase();
      if (icao.length != 4) continue;

      airports[icao] = Airport(
        icao: icao,
        name: row[nameIdx].toString(),
        lat: double.tryParse(row[latIdx].toString()) ?? 0.0,
        lon: double.tryParse(row[lonIdx].toString()) ?? 0.0,
        elevationFt: double.tryParse(row[elevIdx].toString()),
        runways: [], // Ensure explicit modifiable list
      );
    }

    final runwaysData = decoder.convert(runwaysCsv);
    if (runwaysData.isEmpty) return;

    final rwHeader = runwaysData[0].map((e) => e.toString()).toList();
    final airportIdentIdx = rwHeader.indexOf('airport_ident');
    final lengthFtIdx = rwHeader.indexOf('length_ft');
    final leIdentIdx = rwHeader.indexOf('le_ident');
    final heIdentIdx = rwHeader.indexOf('he_ident');
    final leHdgIdx = rwHeader.indexOf('le_heading_degT');
    final heHdgIdx = rwHeader.indexOf('he_heading_degT');
    final leElevIdx = rwHeader.indexOf('le_elevation_ft');
    final heElevIdx = rwHeader.indexOf('he_elevation_ft');

    for (var i = 1; i < runwaysData.length; i++) {
      final row = runwaysData[i];
      if (row.length <= airportIdentIdx) continue;

      final icao = row[airportIdentIdx].toString().trim().toUpperCase();
      final airport = airports[icao];
      if (airport == null) continue;

      final lengthFt = double.tryParse(row[lengthFtIdx].toString()) ?? 0.0;
      final lengthM = lengthFt * 0.3048;

      final leIdent = row[leIdentIdx].toString().trim().toUpperCase();
      final heIdent = row[heIdentIdx].toString().trim().toUpperCase();

      if (leIdent.isNotEmpty) {
        airport.runways.add(Runway(
          id: leIdent,
          heading: (double.tryParse(row[leHdgIdx].toString()) ?? 0.0).round(),
          lengthM: lengthM,
          elevationFt: double.tryParse(row[leElevIdx].toString()),
        ));
      }

      if (heIdent.isNotEmpty) {
        airport.runways.add(Runway(
          id: heIdent,
          heading: (double.tryParse(row[heHdgIdx].toString()) ?? 0.0).round(),
          lengthM: lengthM,
          elevationFt: double.tryParse(row[heElevIdx].toString()),
        ));
      }
    }
  }

  void _buildNavaidsDb(String navaidsCsv) {
    const decoder = CsvDecoder();
    final navaidsData = decoder.convert(navaidsCsv);
    if (navaidsData.isEmpty) return;

    final header = navaidsData[0].map((e) => e.toString()).toList();
    final identIdx = header.indexOf('ident');
    final nameIdx = header.indexOf('name');
    final typeIdx = header.indexOf('type');
    final latIdx = header.indexOf('latitude_deg');
    final lonIdx = header.indexOf('longitude_deg');

    for (var i = 1; i < navaidsData.length; i++) {
      final row = navaidsData[i];
      if (row.length <= identIdx) continue;

      final ident = row[identIdx].toString().trim().toUpperCase();
      if (ident.isEmpty) continue;

      final navaid = Navaid(
        ident: ident,
        name: row[nameIdx].toString(),
        type: row[typeIdx].toString(),
        lat: double.tryParse(row[latIdx].toString()) ?? 0.0,
        lon: double.tryParse(row[lonIdx].toString()) ?? 0.0,
      );

      if (!navaids.containsKey(ident)) {
        navaids[ident] = [];
      }
      navaids[ident]!.add(navaid);
    }
  }
}
