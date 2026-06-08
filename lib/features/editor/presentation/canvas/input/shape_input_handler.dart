import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import '../../../../domain/models/shape_element.dart';
import '../../../../domain/models/stroke_point.dart';
import '../../../../domain/models/shape_type.dart';
import '../../../../domain/services/shape_recognizer.dart';
import '../../../tool_notifier.dart';

class ShapeInputHandler {
  final void Function(ShapeElement shape) onShapeRecognised;
  final void Function(List<StrokePoint> points) onShapeFallback;
  final ToolState toolState;
  final List<StrokePoint> _rawPoints = [];

  ShapeInputHandler({
    required this.onShapeRecognised,
    required this.onShapeFallback,
    required this.toolState,
  });

  void onPointerDown(PointerDownEvent event) {
    _rawPoints.clear();
    _rawPoints.add(StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure,
    ));
  }

  void onPointerMove(PointerMoveEvent event) {
    _rawPoints.add(StrokePoint(
      x: event.localPosition.dx,
      y: event.localPosition.dy,
      pressure: event.pressure,
    ));
  }

  void onPointerUp(PointerUpEvent event) async {
    final rawOffsets = _rawPoints.map((p) => p.toOffset()).toList();
    
    // TextBox is handled immediately via tap, usually 1 or 2 points
    // if selectedShapeType is textBox, just return a default sized box where tapped.
    // Assuming toolState has `selectedShapeType`. I'll assume it defaults to line if null.
    // Wait, the prompt says "If a shape is recognised: creates ShapeElement... falls back to adding a regular freehand Stroke."
    // Recognition runs in compute isolate:
    final result = await compute(recogniseShape, rawOffsets);
    
    if (result != null) {
      final shape = _buildShapeElement(result, toolState);
      onShapeRecognised(shape);
    } else {
      onShapeFallback(List.from(_rawPoints));
    }
    _rawPoints.clear();
  }

  ShapeElement _buildShapeElement(RecognitionResult result, ToolState toolState) {
    final id = DateTime.now().millisecondsSinceEpoch.toString(); // or uuid
    
    return ShapeElement()
      ..id = id
      ..type = result.type
      ..color = toolState.color.value
      ..strokeWidth = toolState.size
      ..hasFill = false // toolState.hasFill if available
      ..fillColor = toolState.color.value
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
