import 'package:flutter/gestures.dart';
import '../../../domain/models/shape_element.dart';
import '../../../domain/models/stroke_point.dart';
import '../../../domain/models/shape_type.dart';
import '../../../domain/services/shape_recognizer.dart';
import '../../../domain/services/shape_geometry.dart';
import '../../canvas_notifier.dart';
import 'dart:math';

class ShapeInputHandler {
  final void Function(ShapeElement shape) onShapeRecognised;
  final void Function(List<StrokePoint> points) onShapeFallback;
  final ToolState Function() getToolState;
  final void Function(StrokePoint)? onPreviewPointAdd;
  final void Function()? onPreviewEnd;
  final List<StrokePoint> _rawPoints = [];

  ShapeInputHandler({
    required this.onShapeRecognised,
    required this.onShapeFallback,
    required this.getToolState,
    this.onPreviewPointAdd,
    this.onPreviewEnd,
  });

  void onPointerDown(PointerDownEvent event) {
    _rawPoints.clear();
    final pt = StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure,
    );
    _rawPoints.add(pt);
    onPreviewPointAdd?.call(pt);
  }

  void onPointerMove(PointerMoveEvent event) {
    final pt = StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure,
    );
    _rawPoints.add(pt);
    onPreviewPointAdd?.call(pt);
  }

  void onPointerUp(PointerUpEvent event) async {
    final toolState = getToolState();
    final rawOffsets = _rawPoints.map((p) => p.toOffset()).toList();
    if (rawOffsets.isEmpty) return;

    onPreviewEnd?.call();

    if (toolState.selectedShapeType == ShapeType.textBox) {
      final center = rawOffsets.first;
      final geom = [center.dx, center.dy, center.dx + 200, center.dy + 50];
      final shape = _buildShapeElement(RecognitionResult(ShapeType.textBox, geom), toolState);
      onShapeRecognised(shape);
      _rawPoints.clear();
      return;
    }

    if (toolState.selectedShapeType == ShapeType.svgImage) {
      // SVG handled externally, but we can emit a placeholder rect
      final center = rawOffsets.first;
      final geom = [center.dx, center.dy, center.dx + 100, center.dy + 100];
      final shape = _buildShapeElement(RecognitionResult(ShapeType.svgImage, geom), toolState);
      onShapeRecognised(shape);
      _rawPoints.clear();
      return;
    }

    if (rawOffsets.length < 2 || ShapeGeometry.boundingRect(rawOffsets).longestSide < 5.0) {
      onShapeFallback(List.from(_rawPoints));
      _rawPoints.clear();
      return;
    }

    // Instead of using recogniseShape for 'polygon' when it's selected, draw a pentagon.
    // If we want to use the magic recogniser, we could do it when no specific shape is selected.
    final type = toolState.selectedShapeType;
    final rect = ShapeGeometry.boundingRect(rawOffsets);
    final first = rawOffsets.first;
    final last = rawOffsets.last;

    List<double> geom;
    if (type == ShapeType.line) {
      geom = [first.dx, first.dy, last.dx, last.dy];
    } else if (type == ShapeType.arrow) {
      final lineVec = last - first;
      final lineAngle = atan2(lineVec.dy, lineVec.dx);
      final tip1 = last + Offset(cos(lineAngle + pi * 3 / 4), sin(lineAngle + pi * 3 / 4)) * 20;
      final tip2 = last + Offset(cos(lineAngle - pi * 3 / 4), sin(lineAngle - pi * 3 / 4)) * 20;
      geom = [first.dx, first.dy, last.dx, last.dy, tip1.dx, tip1.dy, tip2.dx, tip2.dy];
    } else if (type == ShapeType.circle) {
      geom = [rect.left, rect.top, rect.right, rect.bottom];
    } else if (type == ShapeType.rectangle) {
      geom = [rect.left, rect.top, rect.right, rect.bottom];
    } else if (type == ShapeType.triangle) {
      geom = [rect.left + rect.width / 2, rect.top, rect.right, rect.bottom, rect.left, rect.bottom];
    } else if (type == ShapeType.polygon) {
      geom = [];
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final rx = rect.width / 2;
      final ry = rect.height / 2;
      for (int i = 0; i < 5; i++) {
        final angle = -pi / 2 + (i * 2 * pi / 5);
        geom.add(cx + cos(angle) * rx);
        geom.add(cy + sin(angle) * ry);
      }
    } else {
      geom = [rect.left, rect.top, rect.right, rect.bottom];
    }

    final shape = _buildShapeElement(RecognitionResult(type, geom), toolState);
    onShapeRecognised(shape);
    _rawPoints.clear();
  }

  ShapeElement _buildShapeElement(RecognitionResult result, ToolState toolState) {
    final id = DateTime.now().millisecondsSinceEpoch.toString(); // or uuid
    
    return ShapeElement()
      ..id = id
      ..type = result.type
      ..color = toolState.color.toARGB32()
      ..strokeWidth = toolState.size
      ..hasFill = false // toolState.hasFill if available
      ..fillColor = toolState.color.toARGB32()
      ..opacity = 1.0
      ..rotation = 0.0
      ..text = ''
      ..fontSize = 16
      ..fontFamily = 'Roboto'
      ..isBold = false
      ..isItalic = false
      ..svgRelativePath = ''
      ..zOrder = DateTime.now().millisecondsSinceEpoch
      ..geometryData = result.geometryData;
  }
}
