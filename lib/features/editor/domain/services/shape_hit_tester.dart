import 'dart:math';
import 'package:flutter/material.dart';
import '../models/shape_element.dart';
import '../models/shape_type.dart';
import 'shape_geometry.dart';

/// Hit-testing for shapes against a single point (used by the eraser).
///
/// A shape is "hit" when the point lands within [radius] of its drawn outline,
/// or anywhere inside its body for area-type shapes (text boxes, images, and
/// filled shapes). Rotation is handled by transforming the test point into the
/// shape's local, unrotated space.
class ShapeHitTester {
  static bool isHit(ShapeElement shape, Offset point, double radius) {
    final local = _toLocal(shape, point);
    final r2 = radius * radius;

    for (final (a, b) in _outlineSegments(shape)) {
      if (_distanceSqToSegment(local, a, b) <= r2) return true;
    }

    if (_isAreaShape(shape) && _containsLocal(shape, local)) return true;

    return false;
  }

  static bool _isAreaShape(ShapeElement shape) {
    return shape.type == ShapeType.textBox ||
        shape.type == ShapeType.svgImage ||
        shape.hasFill;
  }

  /// Rotates [point] by -rotation around the shape centre so it can be tested
  /// against the shape's unrotated geometry.
  static Offset _toLocal(ShapeElement shape, Offset point) {
    if (shape.rotation == 0) return point;
    final c = _centre(shape);
    final cosA = cos(-shape.rotation);
    final sinA = sin(-shape.rotation);
    final dx = point.dx - c.dx;
    final dy = point.dy - c.dy;
    return Offset(
      c.dx + dx * cosA - dy * sinA,
      c.dy + dx * sinA + dy * cosA,
    );
  }

  static Offset _centre(ShapeElement shape) {
    switch (shape.type) {
      case ShapeType.circle:
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return ShapeGeometry.rectFromGeometry(shape.geometryData).center;
      case ShapeType.line:
      case ShapeType.arrow:
        final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
        return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final verts = ShapeGeometry.verticesFromGeometry(shape.geometryData);
        return verts.isEmpty ? Offset.zero : ShapeGeometry.centroid(verts);
    }
  }

  static List<(Offset, Offset)> _outlineSegments(ShapeElement shape) {
    switch (shape.type) {
      case ShapeType.line:
      case ShapeType.arrow:
        final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
        return [(start, end)];
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return _rectSegments(ShapeGeometry.rectFromGeometry(shape.geometryData));
      case ShapeType.circle:
        return _ellipseSegments(ShapeGeometry.rectFromGeometry(shape.geometryData));
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        return _polygonSegments(
            ShapeGeometry.verticesFromGeometry(shape.geometryData));
    }
  }

  static List<(Offset, Offset)> _rectSegments(Rect r) {
    return [
      (r.topLeft, r.topRight),
      (r.topRight, r.bottomRight),
      (r.bottomRight, r.bottomLeft),
      (r.bottomLeft, r.topLeft),
    ];
  }

  static List<(Offset, Offset)> _polygonSegments(List<Offset> verts) {
    if (verts.length < 2) return const [];
    final segs = <(Offset, Offset)>[];
    for (int i = 0; i < verts.length; i++) {
      segs.add((verts[i], verts[(i + 1) % verts.length]));
    }
    return segs;
  }

  static List<(Offset, Offset)> _ellipseSegments(Rect r, [int steps = 32]) {
    final cx = r.center.dx, cy = r.center.dy;
    final rx = r.width / 2, ry = r.height / 2;
    final pts = <Offset>[];
    for (int i = 0; i < steps; i++) {
      final a = (i / steps) * 2 * pi;
      pts.add(Offset(cx + cos(a) * rx, cy + sin(a) * ry));
    }
    return _polygonSegments(pts);
  }

  static bool _containsLocal(ShapeElement shape, Offset p) {
    switch (shape.type) {
      case ShapeType.circle:
        final r = ShapeGeometry.rectFromGeometry(shape.geometryData);
        final rx = r.width / 2, ry = r.height / 2;
        if (rx == 0 || ry == 0) return false;
        final nx = (p.dx - r.center.dx) / rx;
        final ny = (p.dy - r.center.dy) / ry;
        return nx * nx + ny * ny <= 1.0;
      case ShapeType.rectangle:
      case ShapeType.textBox:
      case ShapeType.svgImage:
        return ShapeGeometry.rectFromGeometry(shape.geometryData).contains(p);
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        return _pointInPolygon(
            p, ShapeGeometry.verticesFromGeometry(shape.geometryData));
      case ShapeType.line:
      case ShapeType.arrow:
        return false;
    }
  }

  static bool _pointInPolygon(Offset point, List<Offset> poly) {
    if (poly.length < 3) return false;
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      final pi = poly[i], pj = poly[j];
      if (((pi.dy > point.dy) != (pj.dy > point.dy)) &&
          (point.dx <
              (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  static double _distanceSqToSegment(Offset p, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final l2 = dx * dx + dy * dy;
    if (l2 == 0) {
      final ex = p.dx - a.dx, ey = p.dy - a.dy;
      return ex * ex + ey * ey;
    }
    double t = ((p.dx - a.dx) * dx + (p.dy - a.dy) * dy) / l2;
    t = t.clamp(0.0, 1.0);
    final projX = a.dx + t * dx;
    final projY = a.dy + t * dy;
    final ex = p.dx - projX, ey = p.dy - projY;
    return ex * ex + ey * ey;
  }
}
