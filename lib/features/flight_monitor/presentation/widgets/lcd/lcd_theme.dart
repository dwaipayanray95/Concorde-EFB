import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Vivid avionics color palette shared by every LCD panel module.
const Color lcdAccent = Color(0xFF00E5FF); // electric cyan
const Color lcdAccentGlow = Color(0x5500E5FF); // cyan glow — used in box shadows

const Color lcdGreen = Color(0xFF00E676); // bright emerald
const Color lcdAmber = Color(0xFFFFAB40); // amber warning
const Color lcdRed = Color(0xFFFF5252); // alert red
const Color lcdBg = Color(0xFF050D1A); // deep navy-black
const Color lcdPanelBg = Color(0xFF0B1628); // slightly lighter navy
const Color lcdCard = Color(0xFF0F1F38); // card inner bg
const Color lcdBorder = Color(0xFF1B3A5C); // visible border

const Color lcdLabelColor = Color(0xFF8ECAE6); // bright blue-grey label
const Color lcdMuted = Color(0xFF546E7A); // muted text
const Color lcdSky = Color(0xFF0D47A1); // real horizon blue
const Color lcdGround = Color(0xFF4A2900); // earth brown

TextStyle lcdMono({
  double size = 11,
  Color color = Colors.white,
  FontWeight weight = FontWeight.bold,
}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

TextStyle lcdLabel({double size = 9, Color color = lcdLabelColor}) =>
    GoogleFonts.plusJakartaSans(
        fontSize: size, color: color, fontWeight: FontWeight.w700, letterSpacing: 1.0);
