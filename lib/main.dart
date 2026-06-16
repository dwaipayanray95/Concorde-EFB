import 'package:flutter/material.dart';
import 'core/ui_tokens.dart';
import 'screens/home_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
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
