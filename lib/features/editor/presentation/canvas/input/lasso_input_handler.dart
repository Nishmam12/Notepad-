import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
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

  void onPointerDown(PointerDownEvent event) {
    _lassoPath.clear();
    _lassoPath.add(event.localPosition);
    onLassoUpdate(List.from(_lassoPath));
  }

  void onPointerMove(PointerMoveEvent event) {
    _lassoPath.add(event.localPosition);
    onLassoUpdate(List.from(_lassoPath));
  }

  void onPointerUp(PointerUpEvent event) async {
    if (_lassoPath.length < 3) {
      _lassoPath.clear();
      onLassoUpdate([]);
      return;
    }

    final currentStrokes = getCurrentStrokes();
    final currentShapes = getCurrentShapes();

    final input = LassoHitTestInput(
      lassoPath: List.from(_lassoPath),
      strokes: currentStrokes,
      shapes: currentShapes,
    );

    final result = await compute(runLassoHitTest, input);

    if (!result.isEmpty) {
      final bounds = _computeSelectionBounds(result, currentStrokes, currentShapes);
      onLassoComplete(result, bounds);
    } else {
      // Clear selection if tapping/lassoing empty space
      onLassoComplete(result, Rect.zero);
    }
    
    _lassoPath.clear();
    onLassoUpdate([]);
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
          // Fallback for line/circle geometry parsing
          final pts = _extractAllGeomPoints(shape);
          allPoints.addAll(pts);
        }
      }
    }

    return ShapeGeometry.boundingRect(allPoints);
  }

  List<Offset> _extractAllGeomPoints(ShapeElement shape) {
    if (shape.geometryData.isEmpty) return [];
    if (shape.geometryData.length >= 4 && (shape.type == ShapeType.circle || shape.type == ShapeType.rectangle || shape.type == ShapeType.textBox || shape.type == ShapeType.svgImage)) {
      final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
      return [rect.topLeft, rect.bottomRight];
    }
    
    final List<Offset> pts = [];
    for (int i=0; i<shape.geometryData.length-1; i+=2) {
      pts.add(Offset(shape.geometryData[i], shape.geometryData[i+1]));
    }
    return pts;
  }
}
