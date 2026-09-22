import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color bg;
  final Color surface;
  final Color resultsBg;
  final Color inputBg;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDim;
  final Color divider;
  final Color dividerStrong;
  final Color accent;
  final Color cardAccent;
  final Color departure;
  final Color arrival;
  final Color errorBg;
  final Color error;
  final Color successBg;
  final Color success;
  final Color mvfrBg;
  final Color mvfr;
  final Color ifrBg;
  final Color ifr;
  final Color lifrBg;
  final Color lifr;

  const AppColors({
    required this.bg,
    required this.surface,
    required this.resultsBg,
    required this.inputBg,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDim,
    required this.divider,
    required this.dividerStrong,
    required this.accent,
    required this.cardAccent,
    required this.departure,
    required this.arrival,
    required this.errorBg,
    required this.error,
    required this.successBg,
    required this.success,
    required this.mvfrBg,
    required this.mvfr,
    required this.ifrBg,
    required this.ifr,
    required this.lifrBg,
    required this.lifr,
  });

  static const light = AppColors(
    bg: Color(0xFFF1F3F7),
    surface: Color(0xFFE2E6EF),
    resultsBg: Color(0xFFFFFFFF),
    inputBg: Color(0xFFF8FAFD),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF334155),
    textDim: Color(0xFF64748B),
    divider: Color(0xFFCBD5E1),
    dividerStrong: Color(0xFF94A3B8),
    accent: Color(0xFFD97706), // Aviation Amber Lead (Light Mode)
    cardAccent: Color(0xFF0284C7), // High-Viz Sky Blue
    departure: Color(0xFF059669), // Emerald VFR
    arrival: Color(0xFF0284C7), // Cyan Info/Arrival
    errorBg: Color(0xFFFEE2E2),
    error: Color(0xFFDC2626), // Ruby Alert
    successBg: Color(0xFFD1FAE5),
    success: Color(0xFF059669), // Emerald
    mvfrBg: Color(0xFFFEF3C7),
    mvfr: Color(0xFFD97706), // Amber Caution
    ifrBg: Color(0xFFFFEDD5),
    ifr: Color(0xFFEA580C),
    lifrBg: Color(0xFFF5D0FE),
    lifr: Color(0xFFC026D3),
  );

  static const dark = AppColors(
    bg: Color(0xFF090B10), // Deep obsidian cockpit canvas
    surface: Color(0xFF131722), // Low-reflection gunmetal surface
    resultsBg: Color(0xFF191F2D), // Inset instrument/readout panel
    inputBg: Color(0xFF111520), // Recessed input well
    textPrimary: Color(0xFFF8FAFC), // Crisp anti-glare primary readout
    textSecondary: Color(0xFF94A3B8), // Cool slate secondary
    textDim: Color(0xFF64748B), // Muted captions & units
    divider: Color(0xFF1E2638), // Subtle 1px instrument border
    dividerStrong: Color(0xFF2E3B54), // Outer bezel framing
    accent: Color(0xFFF59E0B), // Signature Aviation Amber (Dark Mode)
    cardAccent: Color(0xFF38BDF8), // Cyan/Sky Blue alert & enroute
    departure: Color(0xFF10B981), // Emerald VFR / DEP
    arrival: Color(0xFF38BDF8), // Cyan ARR / Sim telemetry
    errorBg: Color(0xFF3B1219),
    error: Color(0xFFEF4444), // Master Warning Red
    successBg: Color(0xFF0B2E1E),
    success: Color(0xFF10B981), // Within limits / Safe Green
    mvfrBg: Color(0xFF382307),
    mvfr: Color(0xFFF59E0B), // Master Caution Amber
    ifrBg: Color(0xFF361608),
    ifr: Color(0xFFF97316),
    lifrBg: Color(0xFF311038),
    lifr: Color(0xFFE879F9),
  );

  @override
  AppColors copyWith({
    Color? bg,
    Color? surface,
    Color? resultsBg,
    Color? inputBg,
    Color? textPrimary,
    Color? textSecondary,
    Color? textDim,
    Color? divider,
    Color? dividerStrong,
    Color? accent,
    Color? cardAccent,
    Color? departure,
    Color? arrival,
    Color? errorBg,
    Color? error,
    Color? successBg,
    Color? success,
    Color? mvfrBg,
    Color? mvfr,
    Color? ifrBg,
    Color? ifr,
    Color? lifrBg,
    Color? lifr,
  }) {
    return AppColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      resultsBg: resultsBg ?? this.resultsBg,
      inputBg: inputBg ?? this.inputBg,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textDim: textDim ?? this.textDim,
      divider: divider ?? this.divider,
      dividerStrong: dividerStrong ?? this.dividerStrong,
      accent: accent ?? this.accent,
      cardAccent: cardAccent ?? this.cardAccent,
      departure: departure ?? this.departure,
      arrival: arrival ?? this.arrival,
      errorBg: errorBg ?? this.errorBg,
      error: error ?? this.error,
      successBg: successBg ?? this.successBg,
      success: success ?? this.success,
      mvfrBg: mvfrBg ?? this.mvfrBg,
      mvfr: mvfr ?? this.mvfr,
      ifrBg: ifrBg ?? this.ifrBg,
      ifr: ifr ?? this.ifr,
      lifrBg: lifrBg ?? this.lifrBg,
      lifr: lifr ?? this.lifr,
    );
  }

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      bg: Color.lerp(bg, other.bg, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      resultsBg: Color.lerp(resultsBg, other.resultsBg, t)!,
      inputBg: Color.lerp(inputBg, other.inputBg, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textDim: Color.lerp(textDim, other.textDim, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      dividerStrong: Color.lerp(dividerStrong, other.dividerStrong, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      cardAccent: Color.lerp(cardAccent, other.cardAccent, t)!,
      departure: Color.lerp(departure, other.departure, t)!,
      arrival: Color.lerp(arrival, other.arrival, t)!,
      errorBg: Color.lerp(errorBg, other.errorBg, t)!,
      error: Color.lerp(error, other.error, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      success: Color.lerp(success, other.success, t)!,
      mvfrBg: Color.lerp(mvfrBg, other.mvfrBg, t)!,
      mvfr: Color.lerp(mvfr, other.mvfr, t)!,
      ifrBg: Color.lerp(ifrBg, other.ifrBg, t)!,
      ifr: Color.lerp(ifr, other.ifr, t)!,
      lifrBg: Color.lerp(lifrBg, other.lifrBg, t)!,
      lifr: Color.lerp(lifr, other.lifr, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
