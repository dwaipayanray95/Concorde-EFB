/// Landing quality bands from touchdown rate of descent and vertical G.
enum LandingRating {
  butter('BUTTER'),
  smooth('SMOOTH'),
  firm('FIRM'),
  hard('HARD'),
  inspection('INSPECTION');

  final String label;
  const LandingRating(this.label);
}

/// 600 fpm / 2.6 g is the certification hard-landing inspection threshold
/// (SKYbrary). The lower bands are indicative only: Concorde lands firmer
/// than airliners (no real flare), so "firm" is normal for her.
LandingRating rateLanding(double fpm, double g) {
  final rate = fpm.abs();
  if (rate >= 600 || g >= 2.6) return LandingRating.inspection;
  if (rate >= 400) return LandingRating.hard;
  if (rate >= 240) return LandingRating.firm;
  if (rate >= 120) return LandingRating.smooth;
  return LandingRating.butter;
}
