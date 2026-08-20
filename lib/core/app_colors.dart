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
    bg: Color(0xFFC0C9DC),
    surface: Color(0xFFD2D9E8),
    resultsBg: Color(0xFFC6CFE2),
    inputBg: Color(0xFFB8C2D8),
    textPrimary: Color(0xFF0C0F1A),
    textSecondary: Color(0xFF384056),
    textDim: Color(0xFF535C75),
    divider: Color(0xFFA8B4CE),
    dividerStrong: Color(0xFF98A6C4),
    accent: Color(0xFF304FFE),
    departure: Color(0xFFFF2D4E),
    arrival: Color(0xFF00B848),
    errorBg: Color(0xFFFFDDE3),
    error: Color(0xFFD50032),
    successBg: Color(0xFFD4F5E2),
    success: Color(0xFF009647),
    mvfrBg: Color(0xFFFFEDCE),
    mvfr: Color(0xFFE68900),
    ifrBg: Color(0xFFFFDED4),
    ifr: Color(0xFFF44315),
    lifrBg: Color(0xFFEED4F7),
    lifr: Color(0xFF9C00EA),
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
    lifrBg: Color(0xFF38153D),
    lifr: Color(0xFFE040FB),
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
