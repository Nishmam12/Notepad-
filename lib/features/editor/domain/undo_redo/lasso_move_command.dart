import 'package:flutter/material.dart';
import '../../domain/models/stroke.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/models/shape_type.dart';
import '../../presentation/canvas_notifier.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

class LassoMoveCommand extends Command {
  final CanvasStateNotifier _canvasNotifier;
  final ShapeNotifier _shapeNotifier;
  
  final Map<String, Offset> _strokeDeltas;
  final Map<String, Offset> _shapeDeltas;
  
  final List<Stroke> _strokesSnapshot;
  final List<ShapeElement> _shapesSnapshot;

  LassoMoveCommand({
    required CanvasStateNotifier canvasNotifier,
    required ShapeNotifier shapeNotifier,
    required Map<String, Offset> strokeDeltas,
    required Map<String, Offset> shapeDeltas,
    required List<Stroke> strokesSnapshot,
    required List<ShapeElement> shapesSnapshot,
  })  : _canvasNotifier = canvasNotifier,
        _shapeNotifier = shapeNotifier,
        _strokeDeltas = strokeDeltas,
        _shapeDeltas = shapeDeltas,
        _strokesSnapshot = strokesSnapshot,
        _shapesSnapshot = shapesSnapshot;

  @override
  void execute() {
    // Apply forward delta
    for (final stroke in _strokesSnapshot) {
      if (_strokeDeltas.containsKey(stroke.id)) {
        final delta = _strokeDeltas[stroke.id]!;
        final newPoints = stroke.points.map((p) => p.copyWith(
          x: p.x + delta.dx, 
          y: p.y + delta.dy
        )).toList();
        _canvasNotifier.updateStroke(stroke.copyWith(points: newPoints));
      }
    }

    for (final shape in _shapesSnapshot) {
      if (_shapeDeltas.containsKey(shape.id)) {
        final delta = _shapeDeltas[shape.id]!;
        final newGeom = _translateGeom(shape, delta);
        // Note: For a clean undo/redo architecture, ShapeElement needs a copyWith or we modify carefully.
        // Actually since ShapeElement is Isar embedded, we create a new instance with the same ID.
        final updated = _cloneWithGeom(shape, newGeom);
        _shapeNotifier.updateShape(updated);
      }
    }
  }

  @override
  void undo() {
    // Apply reverse delta
    for (final stroke in _strokesSnapshot) {
      if (_strokeDeltas.containsKey(stroke.id)) {
        final delta = _strokeDeltas[stroke.id]!;
        final newPoints = stroke.points.map((p) => p.copyWith(
          x: p.x - delta.dx, 
          y: p.y - delta.dy
        )).toList();
        _canvasNotifier.updateStroke(stroke.copyWith(points: newPoints));
      }
    }

    for (final shape in _shapesSnapshot) {
      if (_shapeDeltas.containsKey(shape.id)) {
        final delta = _shapeDeltas[shape.id]!;
        final newGeom = _translateGeom(shape, Offset(-delta.dx, -delta.dy));
        final updated = _cloneWithGeom(shape, newGeom);
        _shapeNotifier.updateShape(updated);
      }
    }
  }
  
  List<double> _translateGeom(ShapeElement shape, Offset delta) {
    if (shape.type == ShapeType.circle || shape.type == ShapeType.rectangle || shape.type == ShapeType.textBox || shape.type == ShapeType.svgImage) {
      return [
        shape.geometryData[0] + delta.dx,
        shape.geometryData[1] + delta.dy,
        shape.geometryData[2] + delta.dx,
        shape.geometryData[3] + delta.dy,
      ];
    } else {
      final List<double> newGeom = [];
      for (int i=0; i<shape.geometryData.length - 1; i+=2) {
        newGeom.add(shape.geometryData[i] + delta.dx);
        newGeom.add(shape.geometryData[i+1] + delta.dy);
      }
      // If arrow has odd number of points? The arrowhead points are also pairs of dx,dy. 
      // So the loop correctly translates all pairs.
      return newGeom;
    }
  }

  ShapeElement _cloneWithGeom(ShapeElement original, List<double> newGeom) {
    return ShapeElement()
      ..id = original.id
      ..type = original.type
      ..color = original.color
      ..strokeWidth = original.strokeWidth
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
