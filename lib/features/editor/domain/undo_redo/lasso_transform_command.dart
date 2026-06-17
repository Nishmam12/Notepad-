import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../domain/models/stroke.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/models/shape_type.dart';
import '../../domain/services/shape_geometry.dart';
import '../../domain/services/binding_service.dart';
import '../../presentation/canvas_notifier.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

/// Applies one rigid/affine transform — a move, a uniform resize anchored at a
/// fixed corner, or a rotation about a centre — to the selected strokes and
/// shapes, and reverses it.
///
/// Only one kind of gesture is active per command, so the parameters compose
/// trivially: a point is scaled about [_anchor], then rotated about [_center],
/// then translated. This matches the canvas preview transform exactly.
///
/// Strokes (which have no rotation field) rotate their points directly. Shapes
/// rotate via their [ShapeElement.rotation] field plus an orbital re-centre, so
/// LTRB-stored shapes (rect/circle/text/svg) stay rigid instead of shearing.
///
/// Undo restores the captured pre-transform snapshot directly, so it is exact
/// and safe to redo repeatedly.
class LassoTransformCommand extends Command {
  final CanvasStateNotifier _canvasNotifier;
  final ShapeNotifier _shapeNotifier;

  final Offset _center;
  final Offset _anchor;
  final double _scale;
  final double _rotation;
  final Offset _translation;

  final Set<String> _strokeIds;
  final Set<String> _shapeIds;

  final List<Stroke> _strokesSnapshot;
  final List<ShapeElement> _shapesSnapshot;

  // Pre-transform state of arrows that were rerouted because a shape they bind
  // to moved; restored verbatim on undo.
  List<ShapeElement> _reroutedArrowsBefore = const [];

  LassoTransformCommand({
    required CanvasStateNotifier canvasNotifier,
    required ShapeNotifier shapeNotifier,
    required Offset center,
    required Set<String> strokeIds,
    required Set<String> shapeIds,
    required List<Stroke> strokesSnapshot,
    required List<ShapeElement> shapesSnapshot,
    Offset? anchor,
    double scale = 1.0,
    double rotation = 0.0,
    Offset translation = Offset.zero,
  })  : _canvasNotifier = canvasNotifier,
        _shapeNotifier = shapeNotifier,
        _center = center,
        _anchor = anchor ?? center,
        _scale = scale,
        _rotation = rotation,
        _translation = translation,
        _strokeIds = strokeIds,
        _shapeIds = shapeIds,
        _strokesSnapshot = strokesSnapshot,
        _shapesSnapshot = shapesSnapshot;

  static Offset _rotateAround(Offset p, Offset c, double a) {
    if (a == 0.0) return p;
    final cos = math.cos(a);
    final sin = math.sin(a);
    final d = p - c;
    return c + Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);
  }

  /// Full map for free points: scale (about anchor) → rotate (about centre) →
  /// translate.
  Offset _applyFull(double x, double y) {
    var p = Offset(x, y);
    if (_scale != 1.0) p = _anchor + (p - _anchor) * _scale;
    if (_rotation != 0.0) p = _rotateAround(p, _center, _rotation);
    return p + _translation;
  }

  /// Scale + translate only (no rotation) — used for shape geometry, whose
  /// rotation is carried by the [ShapeElement.rotation] field instead.
  Offset _applyScaleTranslate(double x, double y) {
    var p = Offset(x, y);
    if (_scale != 1.0) p = _anchor + (p - _anchor) * _scale;
    return p + _translation;
  }

  @override
  void execute() {
    for (final stroke in _strokesSnapshot) {
      if (_strokeIds.contains(stroke.id)) {
        final newPoints = stroke.points.map((p) {
          final t = _applyFull(p.x, p.y);
          return p.copyWith(x: t.dx, y: t.dy);
        }).toList();
        _canvasNotifier.updateStroke(
          stroke.copyWith(points: newPoints, size: stroke.size * _scale),
        );
      }
    }

    for (final shape in _shapesSnapshot) {
      if (_shapeIds.contains(shape.id)) {
        var geom = _applyScaleTranslateGeom(shape.geometryData);

        // Rotation: orbit the shape's centre about [_center] and add the angle
        // to the shape's own rotation, keeping it rigid for every shape type.
        if (_rotation != 0.0) {
          final oldC = _geomCentre(shape.type, geom);
          final newC = _rotateAround(oldC, _center, _rotation);
          final shift = newC - oldC;
          geom = _shiftGeom(geom, shift);
        }

        _shapeNotifier.updateShape(
          _cloneWith(
            shape,
            geom,
            shape.strokeWidth * _scale,
            shape.rotation + _rotation,
          ),
        );
      }
    }

    // Re-anchor arrows bound to a moved shape (and not themselves selected).
    final affectedArrows = _shapesSnapshot
        .where((s) =>
            s.type == ShapeType.arrow &&
            !_shapeIds.contains(s.id) &&
            ((s.startBindingId.isNotEmpty &&
                    _shapeIds.contains(s.startBindingId)) ||
                (s.endBindingId.isNotEmpty &&
                    _shapeIds.contains(s.endBindingId))))
        .toList();
    _reroutedArrowsBefore = affectedArrows;
    if (affectedArrows.isNotEmpty) {
      final rerouted = BindingService.rerouteArrows(
        arrowsToCheck: affectedArrows,
        currentShapes: _shapeNotifier.currentShapes,
        changedShapeIds: _shapeIds,
      );
      for (final a in rerouted) {
        _shapeNotifier.updateShape(a);
      }
    }
  }

  @override
  void undo() {
    for (final stroke in _strokesSnapshot) {
      if (_strokeIds.contains(stroke.id)) {
        _canvasNotifier.updateStroke(stroke);
      }
    }
    for (final shape in _shapesSnapshot) {
      if (_shapeIds.contains(shape.id)) {
        _shapeNotifier.updateShape(
          _cloneWith(shape, List<double>.from(shape.geometryData),
              shape.strokeWidth, shape.rotation),
        );
      }
    }
    // Restore rerouted arrows to their pre-transform geometry.
    for (final arrow in _reroutedArrowsBefore) {
      _shapeNotifier.updateShape(arrow);
    }
  }

  List<double> _applyScaleTranslateGeom(List<double> geom) {
    final out = <double>[];
    for (int i = 0; i + 1 < geom.length; i += 2) {
      final t = _applyScaleTranslate(geom[i], geom[i + 1]);
      out.add(t.dx);
      out.add(t.dy);
    }
    if (geom.length.isOdd) out.add(geom.last);
    return out;
  }

  List<double> _shiftGeom(List<double> geom, Offset shift) {
    final out = List<double>.from(geom);
    for (int i = 0; i + 1 < out.length; i += 2) {
      out[i] += shift.dx;
      out[i + 1] += shift.dy;
    }
    return out;
  }

  Offset _geomCentre(ShapeType type, List<double> geom) {
    if (type == ShapeType.circle ||
        type == ShapeType.rectangle ||
        type == ShapeType.textBox ||
        type == ShapeType.svgImage) {
      return ShapeGeometry.rectFromGeometry(geom).center;
    } else if (type == ShapeType.line || type == ShapeType.arrow) {
      final (start, end) = ShapeGeometry.lineFromGeometry(geom);
      return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    }
    final verts = ShapeGeometry.verticesFromGeometry(geom);
    if (verts.isEmpty) {
      return geom.length >= 2 ? Offset(geom[0], geom[1]) : Offset.zero;
    }
    return ShapeGeometry.centroid(verts);
  }

  ShapeElement _cloneWith(ShapeElement original, List<double> newGeom,
      double strokeWidth, double rotation) {
    return original.copyWith(
      geometryData: newGeom,
      strokeWidth: strokeWidth,
      rotation: rotation,
    );
  }
}
