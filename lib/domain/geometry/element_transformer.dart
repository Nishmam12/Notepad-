// Applies move / scale / rotate to a unified [SceneElement], returning a new
// immutable element. Mirrors the proven 1.0.2 lasso transform:
//   * Freehand ink bakes the transform into its points (it has no rotation
//     field at paint time).
//   * Shapes/text/image scale/translate their geometry; rotation is applied via
//     the `rotation` field plus orbiting the element's centre, so the geometry
//     stays rigid (matching how the painter rotates them).
// Stroke width is a style and is not scaled; freehand nib size and font size
// scale with the element so ink/text grow when resized.

import 'dart:ui';

import '../model/scene_element.dart';
import 'geometry_utils.dart';
import 'scene_geometry.dart';

class SceneTransformer {
  SceneTransformer._();

  static SceneElement translate(SceneElement e, Offset d) =>
      _mapGeometry(e, (p) => p + d);

  static SceneElement scaleAbout(
      SceneElement e, double sx, double sy, Offset anchor) {
    final scaled = _mapGeometry(
      e,
      (p) => Offset(
        anchor.dx + (p.dx - anchor.dx) * sx,
        anchor.dy + (p.dy - anchor.dy) * sy,
      ),
    );
    final avg = (sx.abs() + sy.abs()) / 2;
    if (scaled is FreehandElement) {
      return scaled.copyWith(size: scaled.size * avg);
    }
    if (scaled is TextElement) {
      return scaled.copyWith(fontSize: scaled.fontSize * avg);
    }
    return scaled;
  }

  static SceneElement rotateAbout(SceneElement e, double angle, Offset center) {
    if (e is FreehandElement) {
      return e.copyWith(
        points: e.points.map((sp) {
          final r = GeometryUtils.rotatePoint(Offset(sp.x, sp.y), center, angle);
          return sp.copyWith(x: r.dx, y: r.dy);
        }).toList(),
      );
    }
    // Shapes/text/image: orbit the element centre and add to the rotation field.
    final gc = SceneGeometry.center(e);
    final nc = GeometryUtils.rotatePoint(gc, center, angle);
    final moved = translate(e, nc - gc);
    return _withRotation(moved, e.rotation + angle);
  }

  static SceneElement _mapGeometry(SceneElement e, Offset Function(Offset) f) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(
          points: e.points.map((sp) {
            final p = f(Offset(sp.x, sp.y));
            return sp.copyWith(x: p.dx, y: p.dy);
          }).toList(),
        );
      case SceneShapeElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
      case TextElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
      case ImageElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
      case FrameElement():
        return e.copyWith(geometryData: _mapPairs(e.geometryData, f));
    }
  }

  static List<double> _mapPairs(List<double> g, Offset Function(Offset) f) {
    final out = List<double>.from(g);
    for (int i = 0; i + 1 < out.length; i += 2) {
      final p = f(Offset(out[i], out[i + 1]));
      out[i] = p.dx;
      out[i + 1] = p.dy;
    }
    return out;
  }

  static SceneElement _withRotation(SceneElement e, double rot) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(rotation: rot);
      case SceneShapeElement():
        return e.copyWith(rotation: rot);
      case TextElement():
        return e.copyWith(rotation: rot);
      case ImageElement():
        return e.copyWith(rotation: rot);
      case FrameElement():
        return e.copyWith(rotation: rot);
    }
  }
}
