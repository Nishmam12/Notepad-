// Element/stroke eraser hit-testing: which elements does an eraser stroke
// segment (a → b, with [radius]) touch? Samples along the segment against each
// element's inflated world bounds so fast swipes don't skip elements.

import 'dart:ui';

import '../geometry/scene_geometry.dart';
import '../model/scene_element.dart';

class EraserService {
  EraserService._();

  static Set<String> hitAlongSegment({
    required Offset a,
    required Offset b,
    required double radius,
    required List<SceneElement> elements,
    Set<String> skip = const {},
  }) {
    final hits = <String>{};
    for (final e in elements) {
      if (skip.contains(e.id) || e.isLocked) continue;
      final box = SceneGeometry.worldAabb(e).inflate(radius);
      if (_segmentHitsRect(a, b, box)) hits.add(e.id);
    }
    return hits;
  }

  static bool _segmentHitsRect(Offset a, Offset b, Rect r) {
    if (r.contains(a) || r.contains(b)) return true;
    final length = (b - a).distance;
    final steps = (length / 4).ceil().clamp(1, 512);
    for (int i = 1; i < steps; i++) {
      if (r.contains(Offset.lerp(a, b, i / steps)!)) return true;
    }
    return false;
  }
}
