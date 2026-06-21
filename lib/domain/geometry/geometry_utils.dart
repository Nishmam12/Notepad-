// Low-level geometry helpers, ported from Excalidraw's math utilities.
//
// Kept dependency-free (dart:ui Offset/Rect only) so they are trivially unit
// testable and reusable across hit-testing, snapping and eraser logic.

import 'dart:math' as math;
import 'dart:ui';

class GeometryUtils {
  GeometryUtils._();

  /// Shortest distance from [p] to the segment [a]–[b].
  static double pointToSegmentDistance(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (p - a).distance; // a == b
    // Project p onto the line, clamped to the segment.
    double t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * dx, a.dy + t * dy);
    return (p - proj).distance;
  }

  /// Whether two axis-aligned rectangles overlap (touching edges count).
  static bool rectsIntersect(Rect a, Rect b) =>
      a.left <= b.right &&
      b.left <= a.right &&
      a.top <= b.bottom &&
      b.top <= a.bottom;

  /// Even-odd point-in-polygon test over a closed [polygon].
  static bool pointInPolygon(Offset p, List<Offset> polygon) {
    if (polygon.length < 3) return false;
    bool inside = false;
    for (int i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final pi = polygon[i];
      final pj = polygon[j];
      final intersects = (pi.dy > p.dy) != (pj.dy > p.dy) &&
          p.dx <
              (pj.dx - pi.dx) * (p.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx;
      if (intersects) inside = !inside;
    }
    return inside;
  }

  /// Rotates [p] around [centre] by [radians] (clockwise in screen space).
  static Offset rotatePoint(Offset p, Offset centre, double radians) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    final dx = p.dx - centre.dx;
    final dy = p.dy - centre.dy;
    return Offset(
      centre.dx + dx * c - dy * s,
      centre.dy + dx * s + dy * c,
    );
  }
}
