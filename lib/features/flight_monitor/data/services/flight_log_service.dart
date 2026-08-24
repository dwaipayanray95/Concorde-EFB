import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/flight_log_entry.dart';

/// Persists auto-logged [FlightLogEntry] rows to a single index file --
/// unlike the old FlightRecorderService, there's no per-flight frame file
/// (nothing to play back), so this is just index read/append/remove.
class FlightLogService {
  /// On Windows this is the install folder (next to the .exe) rather than
  /// Documents -- Windows Defender's Controlled Folder Access protects
  /// Documents by default and blocks writes there from unrecognized apps.
  /// Other platforms keep using the app documents directory.
  Future<Directory> _appDataRoot() async {
    if (!kIsWeb && Platform.isWindows) {
      return Directory(File(Platform.resolvedExecutable).parent.path);
    }
    return getApplicationDocumentsDirectory();
  }

  Future<File> _indexFile() async {
    final appDir = await _appDataRoot();
    return File('${appDir.path}/concorde_efb/flights_index.json');
  }

  Future<List<FlightLogEntry>> loadHistory() async {
    final file = await _indexFile();
    if (!await file.exists()) return [];

    try {
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      return decoded
          .map((item) => FlightLogEntry.fromJson(item))
          .toList()
          .reversed
          .toList(); // Newest first
    } catch (_) {
      return [];
    }
  }

  Future<void> saveEntry(FlightLogEntry entry) async {
    try {
      final file = await _indexFile();
      List<FlightLogEntry> current = [];

      if (await file.exists()) {
        try {
          final content = await file.readAsString();
          final List<dynamic> decoded = jsonDecode(content);
          current = decoded
              .map((item) => FlightLogEntry.fromJson(item))
              .toList();
        } catch (_) {}
      }

      current.add(entry);

      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode(current.map((e) => e.toJson()).toList()),
      );
    } catch (_) {
      // Disk full / permission denied / locked file -- lose this one log
      // entry rather than crash the app over a background write.
    }
  }

  Future<void> deleteEntry(String id) async {
    final file = await _indexFile();
    if (!await file.exists()) return;

    try {
      final content = await file.readAsString();
      final List<dynamic> decoded = jsonDecode(content);
      final current =
          decoded.map((item) => FlightLogEntry.fromJson(item)).toList()
            ..removeWhere((e) => e.id == id);

      await file.writeAsString(
        jsonEncode(current.map((e) => e.toJson()).toList()),
      );
    } catch (_) {}
  }
}
