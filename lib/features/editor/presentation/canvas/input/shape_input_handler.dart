import 'dart:math';
import 'dart:ui' show Offset, Rect;
import '../../../domain/models/shape_element.dart';
import '../../../domain/models/stroke_point.dart';
import '../../../domain/models/shape_type.dart';
import '../../../domain/services/shape_recognizer.dart';
import '../../canvas_notifier.dart';

class ShapeInputHandler {
  final void Function(ShapeElement shape) onShapeRecognised;
  final void Function(List<StrokePoint> points) onShapeFallback;
  final ToolState Function() getToolState;

  /// Live preview of the shape being dragged. Called with the in-progress
  /// shape on every move, and with `null` when the gesture ends.
  final void Function(ShapeElement? preview)? onPreviewUpdate;
  final List<StrokePoint> _rawPoints = [];

  ShapeInputHandler({
    required this.onShapeRecognised,
    required this.onShapeFallback,
    required this.getToolState,
    this.onPreviewUpdate,
  });

  void onPointerDown(StrokePoint scenePoint) {
    _rawPoints.clear();
    _rawPoints.add(scenePoint);
  }

  void onPointerMove(StrokePoint scenePoint) {
    _rawPoints.add(scenePoint);
    _emitPreview();
  }

  void onPointerUp(StrokePoint scenePoint) {
    final toolState = getToolState();
    final rawOffsets = _rawPoints.map((p) => p.toOffset()).toList();
    if (rawOffsets.isEmpty) return;

    onPreviewUpdate?.call(null);

    if (toolState.selectedShapeType == ShapeType.textBox) {
      final center = rawOffsets.first;
      final geom = [center.dx, center.dy, center.dx + 200, center.dy + 50];
      final shape = _buildShapeElement(RecognitionResult(ShapeType.textBox, geom), toolState);
      onShapeRecognised(shape);
      _rawPoints.clear();
      return;
    }

    if (toolState.selectedShapeType == ShapeType.svgImage) {
      final center = rawOffsets.first;
      final geom = [center.dx, center.dy, center.dx + 100, center.dy + 100];
      final shape = _buildShapeElement(RecognitionResult(ShapeType.svgImage, geom), toolState);
      onShapeRecognised(shape);
      _rawPoints.clear();
      return;
    }

    if (rawOffsets.length < 2 ||
        Rect.fromPoints(rawOffsets.first, rawOffsets.last).longestSide < 5.0) {
      onShapeFallback(List.from(_rawPoints));
      _rawPoints.clear();
      return;
    }

    final geom = _buildGeometry(toolState.selectedShapeType, rawOffsets);
    if (geom == null) {
      onShapeFallback(List.from(_rawPoints));
      _rawPoints.clear();
      return;
    }

    final shape = _buildShapeElement(RecognitionResult(toolState.selectedShapeType, geom), toolState);
    onShapeRecognised(shape);
    _rawPoints.clear();
  }

  /// Builds and emits the live preview shape from the current drag points.
  void _emitPreview() {
    if (onPreviewUpdate == null) return;
    final toolState = getToolState();
    final type = toolState.selectedShapeType;
    // Tap-placed shapes have no meaningful drag preview.
    if (type == ShapeType.textBox || type == ShapeType.svgImage) return;

    final rawOffsets = _rawPoints.map((p) => p.toOffset()).toList();
    final geom = _buildGeometry(type, rawOffsets);
    if (geom == null) {
      onPreviewUpdate!(null);
      return;
    }
    onPreviewUpdate!(_buildShapeElement(RecognitionResult(type, geom), toolState));
  }

  /// Computes geometry data for [type] from the dragged points, or null when
  /// there aren't enough points to form a shape yet.
  List<double>? _buildGeometry(ShapeType type, List<Offset> rawOffsets) {
    if (rawOffsets.length < 2) return null;

    final first = rawOffsets.first;
    final last = rawOffsets.last;
    // Size the shape from the start point to the current point so it can be
    // grown AND shrunk freely mid-drag (Excalidraw-style), rather than from the
    // bounding box of every accumulated point (which can only ever grow).
    final rect = Rect.fromPoints(first, last);

    if (type == ShapeType.line) {
      return [first.dx, first.dy, last.dx, last.dy];
    } else if (type == ShapeType.arrow) {
      final lineVec = last - first;
      final lineAngle = atan2(lineVec.dy, lineVec.dx);
      final tip1 = last + Offset(cos(lineAngle + pi * 3 / 4), sin(lineAngle + pi * 3 / 4)) * 20;
      final tip2 = last + Offset(cos(lineAngle - pi * 3 / 4), sin(lineAngle - pi * 3 / 4)) * 20;
      return [first.dx, first.dy, last.dx, last.dy, tip1.dx, tip1.dy, tip2.dx, tip2.dy];
    } else if (type == ShapeType.circle) {
      return [rect.left, rect.top, rect.right, rect.bottom];
    } else if (type == ShapeType.rectangle) {
      return [rect.left, rect.top, rect.right, rect.bottom];
    } else if (type == ShapeType.triangle) {
      return [rect.left + rect.width / 2, rect.top, rect.right, rect.bottom, rect.left, rect.bottom];
    } else if (type == ShapeType.polygon) {
      final geom = <double>[];
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      final rx = rect.width / 2;
      final ry = rect.height / 2;
      for (int i = 0; i < 5; i++) {
        final angle = -pi / 2 + (i * 2 * pi / 5);
        geom.add(cx + cos(angle) * rx);
        geom.add(cy + sin(angle) * ry);
      }
      return geom;
    } else if (type == ShapeType.diamond) {
      // Excalidraw-style 4-vertex diamond: top, right, bottom, left
      final cx = rect.center.dx;
      final cy = rect.center.dy;
      return [cx, rect.top, rect.right, cy, cx, rect.bottom, rect.left, cy];
    }
    return [rect.left, rect.top, rect.right, rect.bottom];
  }

  ShapeElement _buildShapeElement(RecognitionResult result, ToolState toolState) {
    final id = DateTime.now().millisecondsSinceEpoch.toString();

    return ShapeElement()
      ..id = id
      ..type = result.type
      ..color = toolState.color.toARGB32()
      ..strokeWidth = toolState.size
      ..hasFill = false
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
