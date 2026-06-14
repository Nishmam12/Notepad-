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

  // For each ShapeElement: a shape is selected if its centroid is inside the path.
  for (final shape in shapes) {
    Offset centroid;
    
    switch (shape.type) {
      case ShapeType.textBox:
      case ShapeType.svgImage:
      case ShapeType.circle:
      case ShapeType.rectangle:
        final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
        centroid = rect.center;
        break;
      case ShapeType.line:
      case ShapeType.arrow:
        final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
        centroid = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
        break;
      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final vertices = ShapeGeometry.verticesFromGeometry(shape.geometryData);
        centroid = ShapeGeometry.centroid(vertices);
        break;
    }

    // Apply rotation if needed to check the actual centroid, although centroid is invariant 
    // to rotation around itself. We just need its absolute position which is the centroid.
    if (_isPointInPolygon(centroid, lassoPath)) {
      selectedShapeIds.add(shape.id);
    }
  }

  return LassoHitResult(selectedStrokeIds, selectedShapeIds);
}
