import 'package:flutter/material.dart';
import '../models/stroke.dart';
import '../models/shape_element.dart';
import '../models/shape_type.dart';
import 'shape_geometry.dart';

class LassoHitResult {
  final Set<String> selectedStrokeIds;
  final Set<String> selectedShapeIds;
  const LassoHitResult(this.selectedStrokeIds, this.selectedShapeIds);
  bool get isEmpty => selectedStrokeIds.isEmpty && selectedShapeIds.isEmpty;
}

class LassoHitTestInput {
  final List<Offset> lassoPath;
  final List<Stroke> strokes;
  final List<ShapeElement> shapes;

  const LassoHitTestInput({
    required this.lassoPath,
    required this.strokes,
    required this.shapes,
  });
}

// Top-level function (safe for compute)
LassoHitResult runLassoHitTest(LassoHitTestInput input) {
  return testLasso(
    lassoPath: input.lassoPath,
    strokes: input.strokes,
    shapes: input.shapes,
  );
}

bool _isPointInPolygon(Offset point, List<Offset> polygon) {
  bool isInside = false;
  int j = polygon.length - 1;
  for (int i = 0; i < polygon.length; i++) {
    final pi = polygon[i];
    final pj = polygon[j];
    if (((pi.dy > point.dy) != (pj.dy > point.dy)) &&
        (point.dx < (pj.dx - pi.dx) * (point.dy - pi.dy) / (pj.dy - pi.dy) + pi.dx)) {
      isInside = !isInside;
    }
    j = i;
  }
  return isInside;
}

LassoHitResult testLasso({
  required List<Offset> lassoPath,
  required List<Stroke> strokes,
  required List<ShapeElement> shapes,
}) {
  if (lassoPath.length < 3) return const LassoHitResult({}, {});

  final Set<String> selectedStrokeIds = {};
  final Set<String> selectedShapeIds = {};

  // For each Stroke: a stroke is selected if ANY of its points is inside the path.
  for (final stroke in strokes) {
    for (final point in stroke.points) {
      if (_isPointInPolygon(point.toOffset(), lassoPath)) {
        selectedStrokeIds.add(stroke.id);
        break;
      }
    }
  }

  // For each ShapeElement: a shape is selected if ANY of its representative
  // points (centre, corners, or vertices) falls inside the path. Using more than
  // just the centroid means a lasso drawn tightly around the *visible* content
  // (e.g. short text inside a wide text box) still selects the shape.
  for (final shape in shapes) {
    for (final point in _shapeTestPoints(shape)) {
      if (_isPointInPolygon(point, lassoPath)) {
        selectedShapeIds.add(shape.id);
        break;
      }
    }
  }

  return LassoHitResult(selectedStrokeIds, selectedShapeIds);
}

/// Representative points used to decide whether a shape is captured by a lasso.
List<Offset> _shapeTestPoints(ShapeElement shape) {
  switch (shape.type) {
    case ShapeType.textBox:
    case ShapeType.svgImage:
    case ShapeType.circle:
    case ShapeType.rectangle:
      final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
      return [
        rect.center,
        rect.topLeft,
        rect.topRight,
        rect.bottomLeft,
        rect.bottomRight,
      ];
    case ShapeType.line:
    case ShapeType.arrow:
      final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
      return [start, end, Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2)];
    case ShapeType.triangle:
    case ShapeType.polygon:
    case ShapeType.diamond:
      final vertices = ShapeGeometry.verticesFromGeometry(shape.geometryData);
      if (vertices.isEmpty) return const [];
      return [...vertices, ShapeGeometry.centroid(vertices)];
  }
}
