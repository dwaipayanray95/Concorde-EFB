import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// App version read from the platform at runtime. `pubspec.yaml`'s `version:`
/// is the single source of truth: Flutter stamps it into the Android
/// versionName/Code, the Windows exe resource and the macOS bundle, and
/// `package_info_plus` reads it back from there. Never hardcode it in Dart.
class AppVersionInfo {
  final String version;
  final String build;
  const AppVersionInfo(this.version, this.build);

  /// Shown when the platform can't report a version (e.g. `flutter test`).
  static const unknown = AppVersionInfo('0.0.0', '');

  String get display => build.isEmpty ? 'v$version' : 'v$version ($build)';
}

final appVersionProvider = FutureProvider<AppVersionInfo>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    return AppVersionInfo(info.version, info.buildNumber);
  } catch (_) {
    return AppVersionInfo.unknown;
  }
});
