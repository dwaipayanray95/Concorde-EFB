import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/app_colors.dart';
import 'core/sim_bridge_launcher.dart';
import 'providers/efb_providers.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize AdMob for Mobile platforms
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await MobileAds.instance.initialize();
  }

  // Launch the bundled SimConnect telemetry bridge so Flight Monitor works
  // without the user installing Python or running anything manually, and
  // start watching for MSFS's own process so the bridge gets a fresh
  // restart the moment the game actually launches -- covers opening this
  // app well before starting the sim (see SimBridgeLauncher.startWatching).
  unawaited(SimBridgeLauncher.start());
  SimBridgeLauncher.startWatching();

  // Determine initial window background from persisted theme preference
  final prefs = await SharedPreferences.getInstance();
  final savedTheme = prefs.getString('theme_mode');
  final isDark = savedTheme == 'dark';
  final windowBg = isDark ? AppColors.dark.bg : AppColors.light.bg;

  // Initialize window manager for Desktop platforms
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = WindowOptions(
    size: const Size(1300, 900), // Defined size to fit all widgets comfortably
    center: true,
    backgroundColor: windowBg,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Concorde EFB',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
    await windowManager.setPreventClose(true);
  });

  runApp(const ProviderScope(child: ConcordeEfbApp()));
}

class ConcordeEfbApp extends ConsumerWidget {
  const ConcordeEfbApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      title: 'Concorde EFB',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.light.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.light.accent,
          brightness: Brightness.light,
        ),
        extensions: const [AppColors.light],
        textTheme:
            GoogleFonts.jetBrainsMonoTextTheme(
              ThemeData.light().textTheme,
            ).apply(
              bodyColor: AppColors.light.textPrimary,
              displayColor: AppColors.light.textPrimary,
            ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.dark.bg,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.dark.accent,
          brightness: Brightness.dark,
        ),
        extensions: const [AppColors.dark],
        textTheme:
            GoogleFonts.jetBrainsMonoTextTheme(
              ThemeData.dark().textTheme,
            ).apply(
              bodyColor: AppColors.dark.textPrimary,
              displayColor: AppColors.dark.textPrimary,
            ),
      ),
      home: const HomeScreen(),
    );
  }
}
