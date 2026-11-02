import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../data/flight_log.dart';
import '../domain/landing_rating.dart';

/// Pill colour for a landing rating: good = success, firm = accent, bad = error.
Color ratingColor(AppColors colors, LandingRating r) => switch (r) {
  LandingRating.butter || LandingRating.smooth => colors.success,
  LandingRating.firm => colors.accent,
  LandingRating.hard || LandingRating.inspection => colors.error,
};

/// Text colour that reads on top of [ratingColor].
Color onRatingColor(AppColors colors, LandingRating r) =>
    r == LandingRating.firm ? AppColors.dark.bg : Colors.white;

String fpmText(double fpm) => '−${fpm.abs().round()} FPM';

/// Text of the Flight Monitor touchdown pill.
String touchdownPillText(FlightLog l) {
  final r = l.landingRating;
  if (r == null) return 'LANDED';
  final parts = [
    'LANDED ${fpmText(l.touchdownFpm!)}',
    if (l.touchdownG != null) '${l.touchdownG!.toStringAsFixed(2)} G',
    r == LandingRating.inspection ? '${r.label} — INSPECT' : r.label,
    if (l.bounces > 0) '${l.bounces} BOUNCE${l.bounces > 1 ? 'S' : ''}',
  ];
  return parts.join(' · ');
}

String hm(Duration? d) => d == null
    ? '--'
    : '${d.inHours}:${(d.inMinutes % 60).toString().padLeft(2, '0')}';

String zulu(DateTime? d) => d == null
    ? '--'
    : '${d.hour.toString().padLeft(2, '0')}'
          '${d.minute.toString().padLeft(2, '0')}Z';

const _months = [
  'JAN',
  'FEB',
  'MAR',
  'APR',
  'MAY',
  'JUN',
  'JUL',
  'AUG',
  'SEP',
  'OCT',
  'NOV',
  'DEC',
];

String dateText(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';
