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
