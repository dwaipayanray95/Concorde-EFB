import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color palette and text styles for the redesigned Flight Monitor tab
/// (per the "Flight Monitor Tab" Claude Design import). Kept separate from
/// the app-wide [UiTokens] since this design uses its own darker, cyan-led
/// avionics palette distinct from the rest of the EFB chrome.
const Color fmBg = Color(0xFF070A0F);
const Color fmCard = Color(0xFF0C1119);
const Color fmBorder = Color(0xFF1B2434);
const Color fmAccent = Color(0xFF22D3EE); // electric cyan
const Color fmMuted = Color(0xFF64748B);
const Color fmTextSecondary = Color(0xFF94A3B8);
const Color fmTextDim = Color(0xFF475569);
const Color fmTextPrimary = Color(0xFFF1F5F9);
const Color fmTextFaint = Color(0xFFCBD5E1);

const Color fmGreen = Color(0xFF10B981);
const Color fmRed = Color(0xFFEF4444);
const Color fmAmber = Color(0xFFF59E0B);
const Color fmBlue = Color(0xFF3B82F6);
const Color fmMint = Color(0xFF22C55E);

const Color fmRedDeep = Color(0xFF7F1D1D);
const Color fmAmberDeep = Color(0xFF7C4A05);
const Color fmAmberBg = Color(0xFF1F1608);
const Color fmRedBg = Color(0xFF1F0B0B);

TextStyle fmMono({
  double size = 12,
  Color color = fmTextPrimary,
  FontWeight weight = FontWeight.w800,
}) =>
    GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight);

TextStyle fmLabel({
  double size = 11,
  Color color = fmMuted,
  FontWeight weight = FontWeight.w800,
  double letterSpacing = 1.6,
}) =>
    GoogleFonts.plusJakartaSans(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: letterSpacing,
    );

/// Standard card chrome shared by every supporting-stat card in this tab.
BoxDecoration fmCardDecoration({Color border = fmBorder}) => BoxDecoration(
      color: fmCard,
      border: Border.all(color: border),
      borderRadius: BorderRadius.circular(16),
    );
