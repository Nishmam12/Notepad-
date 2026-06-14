import 'package:flutter/material.dart';
import '../../domain/models/stroke.dart';
import '../../domain/models/shape_element.dart';
import '../../presentation/canvas_notifier.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

/// Applies an affine transform (uniform scale + translation around a fixed
/// centre) to the currently selected strokes and shapes, and reverses it.
///
/// The forward map for a point `p` is:
///   p' = center + (p - center) * scale + translation
/// which exactly matches the live preview matrix used by the canvas layer
/// (translate(translation) · translate(center) · scale(scale) · translate(-center)).
///
/// Undo restores the captured pre-transform snapshot directly, so it is exact
/// regardless of floating-point rounding and is safe to redo repeatedly (the
/// forward transform is always computed from the immutable snapshot).
class LassoTransformCommand extends Command {
  final CanvasStateNotifier _canvasNotifier;
  final ShapeNotifier _shapeNotifier;

  final Offset _center;
  final double _scale;
  final Offset _translation;

  final Set<String> _strokeIds;
  final Set<String> _shapeIds;

  final List<Stroke> _strokesSnapshot;
  final List<ShapeElement> _shapesSnapshot;

  LassoTransformCommand({
    required CanvasStateNotifier canvasNotifier,
    required ShapeNotifier shapeNotifier,
    required Offset center,
    required double scale,
    required Offset translation,
    required Set<String> strokeIds,
    required Set<String> shapeIds,
    required List<Stroke> strokesSnapshot,
    required List<ShapeElement> shapesSnapshot,
  })  : _canvasNotifier = canvasNotifier,
        _shapeNotifier = shapeNotifier,
        _center = center,
        _scale = scale,
        _translation = translation,
        _strokeIds = strokeIds,
        _shapeIds = shapeIds,
        _strokesSnapshot = strokesSnapshot,
        _shapesSnapshot = shapesSnapshot;

  Offset _apply(double x, double y) {
    return _center + (Offset(x, y) - _center) * _scale + _translation;
  }

  @override
  void execute() {
    for (final stroke in _strokesSnapshot) {
      if (_strokeIds.contains(stroke.id)) {
        final newPoints = stroke.points.map((p) {
          final t = _apply(p.x, p.y);
          return p.copyWith(x: t.dx, y: t.dy);
        }).toList();
        _canvasNotifier.updateStroke(
          stroke.copyWith(points: newPoints, size: stroke.size * _scale),
        );
      }
    }

    for (final shape in _shapesSnapshot) {
      if (_shapeIds.contains(shape.id)) {
        _shapeNotifier.updateShape(
          _cloneWithGeom(
            shape,
            _applyGeom(shape.geometryData),
            shape.strokeWidth * _scale,
          ),
        );
      }
    }
  }

  @override
  void undo() {
    // Restore the exact pre-transform snapshot (matched by id by the notifiers).
    for (final stroke in _strokesSnapshot) {
      if (_strokeIds.contains(stroke.id)) {
        _canvasNotifier.updateStroke(stroke);
      }
    }

    for (final shape in _shapesSnapshot) {
      if (_shapeIds.contains(shape.id)) {
        // Clone so the notifier holds a fresh embedded instance (Isar-friendly).
        _shapeNotifier.updateShape(_cloneWithGeom(shape, List<double>.from(shape.geometryData), shape.strokeWidth));
      }
    }
  }

  /// Transforms a flat `[x0,y0, x1,y1, ...]` geometry list pair-wise. Uniform
  /// scale + translation keeps axis-aligned rect geometry valid (no rotation).
  List<double> _applyGeom(List<double> geom) {
    final out = <double>[];
    for (int i = 0; i + 1 < geom.length; i += 2) {
      final t = _apply(geom[i], geom[i + 1]);
      out.add(t.dx);
      out.add(t.dy);
    }
    if (geom.length.isOdd) out.add(geom.last);
    return out;
  }

  ShapeElement _cloneWithGeom(ShapeElement original, List<double> newGeom, double strokeWidth) {
    return ShapeElement()
      ..id = original.id
      ..type = original.type
      ..color = original.color
      ..strokeWidth = strokeWidth
      ..hasFill = original.hasFill
      ..fillColor = original.fillColor
      ..opacity = original.opacity
      ..rotation = original.rotation
      ..text = original.text
      ..fontSize = original.fontSize
      ..fontFamily = original.fontFamily
      ..isBold = original.isBold
      ..isItalic = original.isItalic
      ..svgRelativePath = original.svgRelativePath
      ..zOrder = original.zOrder
      ..geometryData = newGeom;
  }
}
