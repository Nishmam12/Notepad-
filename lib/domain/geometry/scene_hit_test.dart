// Hit-testing for selection: topmost element under a point, and all elements
// overlapping a marquee rectangle. Both work in scene coordinates and account
// for element rotation.

import 'dart:ui';

import '../model/scene_element.dart';
import 'element_bounds.dart';
import 'geometry_utils.dart';
import 'scene_geometry.dart';

class SceneHitTest {
  SceneHitTest._();

  /// Id of the topmost (highest zOrder) element whose body contains [scenePoint].
  static String? topmostAt(
    Offset scenePoint,
    List<SceneElement> elements, {
    bool includeLocked = false,
    double tolerance = 6,
  }) {
    final sorted = [...elements]..sort((a, b) => b.zOrder.compareTo(a.zOrder));
    for (final e in sorted) {
      if (e.isLocked && !includeLocked) continue;
      if (_contains(e, scenePoint, tolerance)) return e.id;
    }
    return null;
  }

  /// Ids of every element whose world bounds intersect [marquee].
  static List<String> within(
    Rect marquee,
    List<SceneElement> elements, {
    bool includeLocked = false,
  }) {
    final hits = <String>[];
    for (final e in elements) {
      if (e.isLocked && !includeLocked) continue;
      if (GeometryUtils.rectsIntersect(SceneGeometry.worldAabb(e), marquee)) {
        hits.add(e.id);
      }
    }
    return hits;
  }

  static bool _contains(SceneElement e, Offset p, double tolerance) {
    // Transform the point into the element's local (un-rotated) frame.
    final local = e.rotation == 0
        ? p
        : GeometryUtils.rotatePoint(p, SceneGeometry.center(e), -e.rotation);
    return ElementBounds.of(e).inflate(tolerance).contains(local);
  }
}
