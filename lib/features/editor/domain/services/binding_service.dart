import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/shape_element.dart';
import '../models/shape_type.dart';
import 'shape_geometry.dart';
import 'shape_hit_tester.dart';

/// Arrow ↔ shape binding, modelled on Excalidraw's `binding.ts`.
///
/// An arrow endpoint can be bound to a shape; the endpoint then re-anchors to
/// the point where the line from the shape centre toward the arrow's other end
/// crosses the shape's edge. This keeps the arrow visually attached when the
/// shape is moved, resized, or rotated.
class BindingService {
  /// Shapes an arrow endpoint may bind to (everything except open linear ones).
  static bool isBindable(ShapeElement shape) {
    switch (shape.type) {
      case ShapeType.rectangle:
      case ShapeType.circle:
      case ShapeType.diamond:
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return true;
      case ShapeType.line:
      case ShapeType.arrow:
        return false;
    }
  }

  /// The topmost bindable shape under [point] (within [radius]), or null.
  static ShapeElement? bindableAt(
      Offset point, List<ShapeElement> shapes, double radius) {
    ShapeElement? best;
    int bestOrder = -1;
    for (final shape in shapes) {
      if (!isBindable(shape)) continue;
      if (_isOver(shape, point, radius)) {
        if (shape.zOrder >= bestOrder) {
          bestOrder = shape.zOrder;
          best = shape;
        }
      }
    }
    return best;
  }

  /// Whether [point] is over [shape] for binding purposes — near its outline OR
  /// anywhere within its body (treating even unfilled shapes as solid, so an
  /// arrow dropped onto a shape binds regardless of fill).
  static bool _isOver(ShapeElement shape, Offset point, double radius) {
    if (ShapeHitTester.isHit(shape, point, radius)) return true;
    final c = centre(shape);
    final local = _rotate(point, c, -shape.rotation);
    return _bounds(shape).inflate(radius).contains(local);
  }

  static Offset centre(ShapeElement shape) {
    switch (shape.type) {
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return ShapeGeometry.rectFromGeometry(shape.geometryData).center;
      case ShapeType.line:
      case ShapeType.arrow:
        final (s, e) = ShapeGeometry.lineFromGeometry(shape.geometryData);
        return Offset((s.dx + e.dx) / 2, (s.dy + e.dy) / 2);
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final v = ShapeGeometry.verticesFromGeometry(shape.geometryData);
        return v.isEmpty ? Offset.zero : ShapeGeometry.centroid(v);
    }
  }

  static Rect _bounds(ShapeElement shape) {
    switch (shape.type) {
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return ShapeGeometry.rectFromGeometry(shape.geometryData);
      default:
        return ShapeGeometry.boundingRect(
            ShapeGeometry.verticesFromGeometry(shape.geometryData));
    }
  }

  static Offset _rotate(Offset p, Offset c, double a) {
    if (a == 0) return p;
    final cos = math.cos(a), sin = math.sin(a);
    final d = p - c;
    return c + Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);
  }

  /// The point on [shape]'s edge along the ray from its centre toward [toward].
  static Offset anchorPoint(ShapeElement shape, Offset toward) {
    final c = centre(shape);
    final bounds = _bounds(shape);
    final hw = bounds.width / 2;
    final hh = bounds.height / 2;
    if (hw <= 0 || hh <= 0) return c;

    // Work in the shape's unrotated frame.
    final localToward = _rotate(toward, c, -shape.rotation);
    final dx = localToward.dx - c.dx;
    final dy = localToward.dy - c.dy;
    if (dx == 0 && dy == 0) return c;

    double t;
    if (shape.type == ShapeType.circle) {
      final nx = dx / hw, ny = dy / hh;
      t = 1 / math.sqrt(nx * nx + ny * ny);
    } else {
      t = 1 / math.max(dx.abs() / hw, dy.abs() / hh);
    }
    final localAnchor = Offset(c.dx + dx * t, c.dy + dy * t);
    return _rotate(localAnchor, c, shape.rotation);
  }

  /// Arrowhead geometry `[sx,sy, ex,ey, t1x,t1y, t2x,t2y]` for an arrow running
  /// [start]→[end] (matches ShapeInputHandler's arrowhead construction).
  static List<double> buildArrowGeometry(Offset start, Offset end) {
    final v = end - start;
    final a = math.atan2(v.dy, v.dx);
    final t1 = end +
        Offset(math.cos(a + math.pi * 3 / 4), math.sin(a + math.pi * 3 / 4)) *
            20;
    final t2 = end +
        Offset(math.cos(a - math.pi * 3 / 4), math.sin(a - math.pi * 3 / 4)) *
            20;
    return [start.dx, start.dy, end.dx, end.dy, t1.dx, t1.dy, t2.dx, t2.dy];
  }

  /// Binds a freshly drawn [arrow]'s endpoints to any bindable shapes they land
  /// on, snapping each bound endpoint to that shape's edge.
  static ShapeElement bindNewArrow(ShapeElement arrow, List<ShapeElement> shapes,
      {double radius = 16}) {
    if (arrow.type != ShapeType.arrow || arrow.geometryData.length < 4) {
      return arrow;
    }
    var start = Offset(arrow.geometryData[0], arrow.geometryData[1]);
    var end = Offset(arrow.geometryData[2], arrow.geometryData[3]);

    final startShape = bindableAt(start, shapes, radius);
    final endShape = bindableAt(end, shapes, radius);

    if (startShape != null) {
      start = anchorPoint(startShape, endShape != null ? centre(endShape) : end);
    }
    if (endShape != null) {
      end = anchorPoint(endShape, startShape != null ? centre(startShape) : start);
    }

    return arrow.copyWith(
      geometryData: buildArrowGeometry(start, end),
      startBindingId: startShape?.id ?? '',
      endBindingId: endShape?.id ?? '',
    );
  }

  /// For every arrow in [arrowsToCheck] bound to a shape in [changedShapeIds],
  /// returns a rerouted copy with its bound endpoint(s) re-anchored to the
  /// current shape positions in [currentShapes].
  static List<ShapeElement> rerouteArrows({
    required List<ShapeElement> arrowsToCheck,
    required List<ShapeElement> currentShapes,
    required Set<String> changedShapeIds,
  }) {
    final byId = {for (final s in currentShapes) s.id: s};
    final out = <ShapeElement>[];

    for (final arrow in arrowsToCheck) {
      if (arrow.type != ShapeType.arrow || arrow.geometryData.length < 4) {
        continue;
      }
      final boundStart = arrow.startBindingId.isNotEmpty
          ? byId[arrow.startBindingId]
          : null;
      final boundEnd =
          arrow.endBindingId.isNotEmpty ? byId[arrow.endBindingId] : null;

      final affected =
          (boundStart != null && changedShapeIds.contains(boundStart.id)) ||
              (boundEnd != null && changedShapeIds.contains(boundEnd.id));
      if (!affected) continue;

      var start = Offset(arrow.geometryData[0], arrow.geometryData[1]);
      var end = Offset(arrow.geometryData[2], arrow.geometryData[3]);

      if (boundStart != null) {
        start = anchorPoint(
            boundStart, boundEnd != null ? centre(boundEnd) : end);
      }
      if (boundEnd != null) {
        end = anchorPoint(
            boundEnd, boundStart != null ? centre(boundStart) : start);
      }

      out.add(arrow.copyWith(geometryData: buildArrowGeometry(start, end)));
    }
    return out;
  }
}
