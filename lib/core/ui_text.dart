import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

TextStyle uiText(
  BuildContext context, {
  required Color color,
  double? size,
  FontWeight? weight,
  double? height,
  double? letterSpacing,
  TextDecoration? decoration,
}) {
  return GoogleFonts.jetBrainsMono(
    color: color,
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    decoration: decoration,
  );
}

/// Standardized typographic hierarchy using JetBrains Mono.
abstract final class AppTypography {
  /// Major title/display headings (20px, bold)
  static TextStyle display(BuildContext context, {required Color color}) =>
      uiText(context, color: color, size: 20, weight: FontWeight.w700);

  /// Card titles and panel headers (14px, semibold)
  static TextStyle sectionHeader(
    BuildContext context, {
    required Color color,
    double letterSpacing = 0.5,
  }) =>
      uiText(
        context,
        color: color,
        size: 14,
        weight: FontWeight.w600,
        letterSpacing: letterSpacing,
      );

  /// Primary body copy and descriptions (12px, regular)
  static TextStyle body(BuildContext context, {required Color color}) =>
      uiText(context, color: color, size: 12, weight: FontWeight.w400);

  /// Instrument readouts, airspeed, altitudes, and avionics dials (13px, bold)
  static TextStyle readout(
    BuildContext context, {
    required Color color,
    double letterSpacing = 0.5,
  }) =>
      uiText(
        context,
        color: color,
        size: 13,
        weight: FontWeight.w700,
        letterSpacing: letterSpacing,
      );

  /// Compact tags, badges, and secondary labels (10px, bold/uppercase)
  static TextStyle caption(
    BuildContext context, {
    required Color color,
    FontWeight weight = FontWeight.w600,
    double letterSpacing = 0.5,
  }) =>
      uiText(
        context,
        color: color,
        size: 10,
        weight: weight,
        letterSpacing: letterSpacing,
      );
}

