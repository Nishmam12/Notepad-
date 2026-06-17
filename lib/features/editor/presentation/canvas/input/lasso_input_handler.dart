import 'package:flutter/foundation.dart';
import 'dart:ui';
import '../../../domain/models/stroke.dart';
import '../../../domain/models/shape_element.dart';
import '../../../domain/models/shape_type.dart';
import '../../../domain/services/shape_geometry.dart';
import '../../../domain/services/lasso_hit_tester.dart';

class LassoInputHandler {
  final void Function(LassoHitResult result, Rect bounds) onLassoComplete;
  final void Function(List<Offset> previewPath) onLassoUpdate;
  final List<Stroke> Function() getCurrentStrokes;
  final List<ShapeElement> Function() getCurrentShapes;

  final List<Offset> _lassoPath = [];

  LassoInputHandler({
    required this.onLassoComplete,
    required this.onLassoUpdate,
    required this.getCurrentStrokes,
    required this.getCurrentShapes,
  });

  void onPointerDown(Offset sceneOffset) {
    _lassoPath.clear();
    _lassoPath.add(sceneOffset);
    onLassoUpdate(List.from(_lassoPath));
  }

  void onPointerMove(Offset sceneOffset) {
    _lassoPath.add(sceneOffset);
    onLassoUpdate(List.from(_lassoPath));
  }

  // A gesture whose bounding box stays under this many scene px is treated as a
  // tap (select the single topmost element) rather than a lasso.
  static const double _tapSpreadThreshold = 10.0;
  // Hit slop for tap-to-select, in scene px.
  static const double _tapTolerance = 12.0;

  void onPointerUp(Offset sceneOffset) async {
    final path = List<Offset>.from(_lassoPath);
    _lassoPath.clear();
    onLassoUpdate([]);

    final currentStrokes = getCurrentStrokes();
    final currentShapes = getCurrentShapes();

    // Tap-to-select: a near-stationary gesture selects the topmost element under
    // the point (or clears the selection when tapping empty space).
    final spread =
        path.isEmpty ? 0.0 : ShapeGeometry.boundingRect(path).longestSide;
    if (path.length < 3 || spread < _tapSpreadThreshold) {
      final point = path.isNotEmpty ? path.first : sceneOffset;
      final result =
          hitTopmost(point, currentStrokes, currentShapes, _tapTolerance);
      if (!result.isEmpty) {
        onLassoComplete(
            result, _computeSelectionBounds(result, currentStrokes, currentShapes));
      } else {
        onLassoComplete(const LassoHitResult({}, {}), Rect.zero);
      }
      return;
    }

    final input = LassoHitTestInput(
      lassoPath: path,
      strokes: currentStrokes,
      shapes: currentShapes,
    );

    final result = await compute(runLassoHitTest, input);

    if (!result.isEmpty) {
      final bounds = _computeSelectionBounds(result, currentStrokes, currentShapes);
      onLassoComplete(result, bounds);
    } else {
      onLassoComplete(result, Rect.zero);
    }
  }

  Rect _computeSelectionBounds(LassoHitResult result, List<Stroke> strokes, List<ShapeElement> shapes) {
    final List<Offset> allPoints = [];

    for (final stroke in strokes) {
      if (result.selectedStrokeIds.contains(stroke.id)) {
        allPoints.addAll(stroke.points.map((p) => p.toOffset()));
      }
    }

    for (final shape in shapes) {
      if (result.selectedShapeIds.contains(shape.id)) {
        final rect = ShapeGeometry.boundingRect(ShapeGeometry.verticesFromGeometry(shape.geometryData));
        if (rect != Rect.zero) {
          allPoints.add(rect.topLeft);
          allPoints.add(rect.bottomRight);
        } else {
          allPoints.addAll(_extractAllGeomPoints(shape));
        }
      }
    }

    return ShapeGeometry.boundingRect(allPoints);
  }

  List<Offset> _extractAllGeomPoints(ShapeElement shape) {
    if (shape.geometryData.isEmpty) return [];
    if (shape.geometryData.length >= 4 &&
        (shape.type == ShapeType.circle ||
            shape.type == ShapeType.rectangle ||
            shape.type == ShapeType.textBox ||
            shape.type == ShapeType.svgImage)) {
      final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
      return [rect.topLeft, rect.bottomRight];
    }

    final List<Offset> pts = [];
    for (int i = 0; i < shape.geometryData.length - 1; i += 2) {
      pts.add(Offset(shape.geometryData[i], shape.geometryData[i + 1]));
    }
    return pts;
  }
}
