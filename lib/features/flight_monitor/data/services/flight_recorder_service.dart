import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../models/telemetry_model.dart';

class FlightRecordHeader {
  final String id;
  final String date;
  final int durationSeconds;
  final double? touchdownVS;
  final double? touchdownPitch;
  final double? touchdownGForce;

  FlightRecordHeader({
    required this.id,
    required this.date,
    required this.durationSeconds,
    this.touchdownVS,
    this.touchdownPitch,
    this.touchdownGForce,
  });

  factory FlightRecordHeader.fromJson(Map<String, dynamic> json) {
    return FlightRecordHeader(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      durationSeconds: json['durationSeconds'] ?? 0,
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
      'touchdownVS': touchdownVS,
      'touchdownPitch': touchdownPitch,
      'touchdownGForce': touchdownGForce,
    };
  }
}

class FlightRecorderService {
  final List<TelemetryModel> _currentSessionFrames = [];
  bool _isRecording = false;
  DateTime? _sessionStartTime;
  
  // Touchdown stats permanently stored for the session
  double? _sessionTouchdownVS;
  double? _sessionTouchdownPitch;
  double? _sessionTouchdownGForce;

  bool get isRecording => _isRecording;
  int get currentFrameCount => _currentSessionFrames.length;

  void startRecording() {
    _currentSessionFrames.clear();
    _sessionStartTime = DateTime.now();
    _isRecording = true;
    _sessionTouchdownVS = null;
    _sessionTouchdownPitch = null;
    _sessionTouchdownGForce = null;
  }

  void addFrame(TelemetryModel frame) {
    if (!_isRecording) return;
    _currentSessionFrames.add(frame);
    
    // Capture and permanently record touchdown variables if they occur
    if (frame.isLanding) {
      _sessionTouchdownVS = frame.touchdownVS;
      _sessionTouchdownPitch = frame.touchdownPitch;
      _sessionTouchdownGForce = frame.touchdownGForce;
    }
  }

  Future<FlightRecordHeader?> stopAndSaveRecording() async {
    if (!_isRecording || _sessionStartTime == null) return null;
    _isRecording = false;

    if (_currentSessionFrames.isEmpty) return null;

    final id = 'flight_${_sessionStartTime!.millisecondsSinceEpoch}';
    final dateStr = _sessionStartTime!.toLocal().toString().substring(0, 19);
    final duration = DateTime.now().difference(_sessionStartTime!).inSeconds;

    final header = FlightRecordHeader(
      id: id,
      date: dateStr,
      durationSeconds: duration,
      touchdownVS: _sessionTouchdownVS,
      touchdownPitch: _sessionTouchdownPitch,
      touchdownGForce: _sessionTouchdownGForce,
    );

    // Save full flight log file
    final dir = await _getFlightsDirectory();
    final file = File('${dir.path}/$id.json');
    final Map<String, dynamic> fullData = {
      'header': header.toJson(),
      'frames': _currentSessionFrames.map((f) => f.toJson()).toList(),
    };
    await file.writeAsString(jsonEncode(fullData));

    // Update master flights index file
    await _registerInIndex(header);
    
    _currentSessionFrames.clear();
    return header;
  }

  Future<Directory> _getFlightsDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final flightsDir = Directory('${appDir.path}/concorde_efb/flights');
    if (!await flightsDir.exists()) {
      await flightsDir.create(recursive: true);
    }
    return flightsDir;
  }

  Future<List<FlightRecordHeader>> loadFlightHistory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final indexFile = File('${appDir.path}/concorde_efb/flights_index.json');
    if (!await indexFile.exists()) return [];

    try {
      final content = await indexFile.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      return decoded.map((item) => FlightRecordHeader.fromJson(item)).toList().reversed.toList(); // Newest first
    } catch (_) {
      return [];
    }
  }

  Future<void> _registerInIndex(FlightRecordHeader header) async {
    final appDir = await getApplicationDocumentsDirectory();
    final indexFile = File('${appDir.path}/concorde_efb/flights_index.json');
    List<FlightRecordHeader> currentList = [];

    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        final List<dynamic> decoded = jsonDecode(content);
        currentList = decoded.map((item) => FlightRecordHeader.fromJson(item)).toList();
      } catch (_) {}
    }

    currentList.add(header);

    final updatedContent = jsonEncode(currentList.map((h) => h.toJson()).toList());
    await indexFile.writeAsString(updatedContent);
  }

  Future<List<TelemetryModel>> loadFlightFrames(String flightId) async {
    final dir = await _getFlightsDirectory();
    final file = File('${dir.path}/$flightId.json');
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      final List<dynamic> framesJson = decoded['frames'] ?? [];
      return framesJson.map((f) => TelemetryModel.fromJson(f)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> deleteFlight(String flightId) async {
    // Delete file
    final dir = await _getFlightsDirectory();
    final file = File('${dir.path}/$flightId.json');
    if (await file.exists()) {
      await file.delete();
    }

    // Remove from index
    final appDir = await getApplicationDocumentsDirectory();
    final indexFile = File('${appDir.path}/concorde_efb/flights_index.json');
    if (await indexFile.exists()) {
      try {
        final content = await indexFile.readAsString();
        final List<dynamic> decoded = jsonDecode(content);
        final List<FlightRecordHeader> currentList = decoded
            .map((item) => FlightRecordHeader.fromJson(item))
            .toList();
        
        currentList.removeWhere((h) => h.id == flightId);

        final updatedContent = jsonEncode(currentList.map((h) => h.toJson()).toList());
        await indexFile.writeAsString(updatedContent);
      } catch (_) {}
    }
  }
}
