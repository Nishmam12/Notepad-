import 'package:flutter/material.dart';

import '../models/stroke.dart';
import '../models/shape_element.dart';
import 'shape_hit_tester.dart';

/// Hit-testing for the stroke eraser, modelled on Excalidraw's `eraserTest`.
///
/// Each pointer move forms the segment between the previous and current eraser
/// positions and tests it against every candidate element, so the result is
/// independent of how fast the eraser moves (a fast swipe never skips an
/// element between sample points). Strokes are width-aware: the tolerance is
/// the eraser [radius] plus half the stroke's width, so thick strokes erase
/// from their visible edge rather than only along their centerline.
class EraserService {
  /// Returns the (strokeIds, shapeIds) hit by the eraser segment [a]→[b].
  /// Ids already in [skipStrokeIds]/[skipShapeIds] are not re-tested.
  static (Set<String>, Set<String>) hitAlongSegment({
    required Offset a,
    required Offset b,
    required double radius,
    required List<Stroke> strokes,
    required List<ShapeElement> shapes,
    Set<String> skipStrokeIds = const {},
    Set<String> skipShapeIds = const {},
  }) {
    final strokeIds = <String>{};
    final shapeIds = <String>{};

    for (final stroke in strokes) {
      if (stroke.isEraser || skipStrokeIds.contains(stroke.id)) continue;
      if (strokeHit(stroke, a, b, radius)) strokeIds.add(stroke.id);
    }
    for (final shape in shapes) {
      if (skipShapeIds.contains(shape.id)) continue;
      if (ShapeHitTester.isHitBySegment(shape, a, b, radius)) {
        shapeIds.add(shape.id);
      }
    }

    return (strokeIds, shapeIds);
  }

  /// True when the eraser segment [a]→[b] comes within `radius + size/2` of any
  /// segment of [stroke]'s centerline.
  static bool strokeHit(Stroke stroke, Offset a, Offset b, double radius) {
    if (stroke.points.isEmpty) return false;
    final tol = radius + stroke.size / 2;
    final tolSq = tol * tol;

    if (stroke.points.length == 1) {
      final p = stroke.points.first;
      return ShapeHitTester.segmentSegmentDistanceSq(
              a, b, Offset(p.x, p.y), Offset(p.x, p.y)) <=
          tolSq;
    }

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final s0 = Offset(stroke.points[i].x, stroke.points[i].y);
      final s1 = Offset(stroke.points[i + 1].x, stroke.points[i + 1].y);
      if (ShapeHitTester.segmentSegmentDistanceSq(a, b, s0, s1) <= tolSq) {
        return true;
      }
    }
    return false;
  }
}
