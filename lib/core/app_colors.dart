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
    required this.lifr,
  });

  static const light = AppColors(
    bg: Color(0xFFF2F4FC),
    surface: Color(0xFFFFFFFF),
    resultsBg: Color(0xFFF8F9FF),
    inputBg: Color(0xFFF2F4FC),
    textPrimary: Color(0xFF1A1C2E),
    textSecondary: Color(0xFF6B6F8A),
    textDim: Color(0xFF8A8DA8),
    divider: Color(0xFFEEF0FA),
    dividerStrong: Color(0xFFE4E7F5),
    accent: Color(0xFF3D5AFE),
    departure: Color(0xFFFF3D57),
    arrival: Color(0xFF00C853),
    errorBg: Color(0xFFFFEBEE),
    error: Color(0xFFD50032),
    successBg: Color(0xFFE4F9EE),
    success: Color(0xFF00A651),
    mvfrBg: Color(0xFFFFF4E0),
    mvfr: Color(0xFFFF9800),
    ifrBg: Color(0xFFFFE8E0),
    ifr: Color(0xFFFF5722),
    lifr: Color(0xFFB300D0),
  );

  static const dark = AppColors(
    bg: Color(0xFF0B0D14),
    surface: Color(0xFF161923),
    resultsBg: Color(0xFF1B1F2C),
    inputBg: Color(0xFF1E222E),
    textPrimary: Color(0xFFF2F4FC),
    textSecondary: Color(0xFFA8ACC4),
    textDim: Color(0xFF6B6F8A),
    divider: Color(0xFF262B3A),
    dividerStrong: Color(0xFF323851),
    accent: Color(0xFF5B7CFF),
    departure: Color(0xFFFF5C74),
    arrival: Color(0xFF2FE07A),
    errorBg: Color(0xFF3A1620),
    error: Color(0xFFFF5C7A),
    successBg: Color(0xFF15301F),
    success: Color(0xFF2FE07A),
    mvfrBg: Color(0xFF3A2C10),
    mvfr: Color(0xFFFFB74D),
    ifrBg: Color(0xFF3A2016),
    ifr: Color(0xFFFF7A50),
    lifr: Color(0xFFDB5FFF),
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
      lifr: Color.lerp(lifr, other.lifr, t)!,
    );
  }
}

extension AppColorsContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}
