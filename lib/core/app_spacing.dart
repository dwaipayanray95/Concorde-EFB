import 'package:flutter/material.dart';

/// Centralized 4px/8px spacing and layout tokens for Concorde EFB.
/// Standardizes spacing across cards, panels, gauges, and navigation rails.
abstract final class AppSpacing {
  static const double xxs = 2.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double xxxl = 32.0;

  // Pre-instantiated EdgeInsets shortcuts
  static const EdgeInsets pXs = EdgeInsets.all(xs);
  static const EdgeInsets pSm = EdgeInsets.all(sm);
  static const EdgeInsets pMd = EdgeInsets.all(md);
  static const EdgeInsets pLg = EdgeInsets.all(lg);
  static const EdgeInsets pXl = EdgeInsets.all(xl);
  static const EdgeInsets pXxl = EdgeInsets.all(xxl);

  // Common horizontal and vertical insets
  static const EdgeInsets hSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets hMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets hLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets vSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets vMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets vLg = EdgeInsets.symmetric(vertical: lg);
}

/// Standardized corner radius tokens.
abstract final class AppRadii {
  static const Radius rXs = Radius.circular(4.0);
  static const Radius rSm = Radius.circular(6.0);
  static const Radius rMd = Radius.circular(8.0);
  static const Radius rLg = Radius.circular(10.0);
  static const Radius rXl = Radius.circular(12.0);

  static const BorderRadius xs = BorderRadius.all(rXs);
  static const BorderRadius sm = BorderRadius.all(rSm);
  static const BorderRadius md = BorderRadius.all(rMd);
  static const BorderRadius lg = BorderRadius.all(rLg);
  static const BorderRadius xl = BorderRadius.all(rXl);
}
