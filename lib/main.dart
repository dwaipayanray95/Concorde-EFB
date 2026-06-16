import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/ui_tokens.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize window manager for Desktop platforms
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1300, 900), // Defined size to fit all widgets comfortably
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.normal,
    title: 'Concorde EFB',
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: ConcordeEfbApp(),
    ),
  );
}

class ConcordeEfbApp extends StatelessWidget {
  const ConcordeEfbApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Concorde EFB',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: UiTokens.bg,
        fontFamily: 'system-ui',
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'system-ui',
          bodyColor: UiTokens.textPrimary,
          displayColor: UiTokens.textPrimary,
        ),
        colorScheme: ColorScheme.fromSeed(
          seedColor: UiTokens.accent,
          brightness: Brightness.dark,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
