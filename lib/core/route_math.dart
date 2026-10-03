import 'dart:math' as math;
import '../models/concorde_models.dart';
import 'concorde_logic.dart';

/// Distances along the planned route (what is actually flown), rather than
/// the great circle between the airports.
class RouteMath {
  RouteMath._();

  /// Total length of a polyline (nm), summed leg by leg.
  static double polylineNm(List<RoutePoint> points) {
    var total = 0.0;
    for (var i = 1; i < points.length; i++) {
      total += ConcordeLogic.greatCircleNM(
        points[i - 1].lat,
        points[i - 1].lon,
        points[i].lat,
        points[i].lon,
      );
    }
    return total;
  }

  /// Distance still to fly along [points] (departure ... arrival) from the
  /// aircraft position: finds the leg the aircraft is closest to, then adds
  /// the distance to that leg's end fix and every remaining leg.
  static double remainingAlongRouteNm(
    double lat,
    double lon,
    List<RoutePoint> points,
  ) {
    if (points.isEmpty) return 0;
    if (points.length == 1) {
      return ConcordeLogic.greatCircleNM(
        lat,
        lon,
        points[0].lat,
        points[0].lon,
      );
    }

    // Suffix sums of leg lengths: after[i] = distance from points[i] to end.
    final after = List<double>.filled(points.length, 0);
    for (var i = points.length - 2; i >= 0; i--) {
      after[i] =
          after[i + 1] +
          ConcordeLogic.greatCircleNM(
            points[i].lat,
            points[i].lon,
            points[i + 1].lat,
            points[i + 1].lon,
          );
    }

    var bestLeg = 0;
    var bestDist = double.infinity;
    for (var i = 0; i < points.length - 1; i++) {
      final d = _distanceToSegmentNm(lat, lon, points[i], points[i + 1]);
      if (d < bestDist) {
        bestDist = d;
        bestLeg = i;
      }
    }
    final next = points[bestLeg + 1];
    return ConcordeLogic.greatCircleNM(lat, lon, next.lat, next.lon) +
        after[bestLeg + 1];
  }

  /// Approximate distance from a point to a leg using a local flat
  /// projection centred on the aircraft (accurate enough to pick the leg).
  static double _distanceToSegmentNm(
    double lat,
    double lon,
    RoutePoint a,
    RoutePoint b,
  ) {
    final k = math.cos(lat * math.pi / 180);
    double dLon(double x) => ((x - lon + 540) % 360 - 180) * k * 60;
    final ax = dLon(a.lon), ay = (a.lat - lat) * 60;
    final bx = dLon(b.lon), by = (b.lat - lat) * 60;
    final vx = bx - ax, vy = by - ay;
    final len2 = vx * vx + vy * vy;
    final t = len2 == 0 ? 0.0 : ((-ax * vx - ay * vy) / len2).clamp(0.0, 1.0);
    final px = ax + t * vx, py = ay + t * vy;
    return math.sqrt(px * px + py * py);
  }
}
