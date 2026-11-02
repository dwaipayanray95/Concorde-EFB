import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';

/// Scrim colour for modal dialogs that dim the app behind them.
Color efbDialogBarrier() => Colors.black.withValues(alpha: 0.55);

/// Wraps a dialog so the app behind it is blurred (use with
/// [efbDialogBarrier] as `barrierColor`) -- keeps Settings and the manual
/// route entry visually consistent.
Widget efbBlurredDialog(Widget dialog) => BackdropFilter(
  filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
  child: dialog,
);
