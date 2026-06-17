import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:inkflow/features/editor/domain/models/stroke.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/editor/domain/models/shape_element.dart';
import 'package:inkflow/features/editor/domain/models/shape_type.dart';
import 'package:inkflow/features/editor/domain/undo_redo/lasso_transform_command.dart';
import 'package:inkflow/features/editor/presentation/canvas_notifier.dart';
import 'package:inkflow/features/editor/presentation/shape_notifier.dart';
import 'package:inkflow/features/editor/data/repositories/shape_repository.dart';

class _MockShapeRepository extends Mock implements ShapeRepository {}

void main() {
  group('LassoTransformCommand', () {
    late CanvasStateNotifier canvas;
    late ShapeNotifier shapes;
    late CanvasState canvasState;
    late ShapeState shapeState;

    setUp(() {
      canvas = CanvasStateNotifier();
      // ShapeNotifier only touches the repository in load/persist paths; the
      // command uses updateShape (memory only), so a mock repo is sufficient.
      shapes = ShapeNotifier(0, _MockShapeRepository());
      // Capture state via the public listener API (avoids protected `state`).
      canvas.addListener((s) => canvasState = s);
      shapes.addListener((s) => shapeState = s);
    });

    Stroke makeStroke() => const Stroke(
          id: 's1',
          color: 0xFF000000,
          size: 4.0,
          opacity: 1.0,
          isEraser: false,
          points: [
            StrokePoint(x: 3, y: 4, pressure: 0.5),
            StrokePoint(x: 5, y: 6, pressure: 0.5),
          ],
        );

    ShapeElement makeRect() => ShapeElement()
      ..id = 'r1'
      ..type = ShapeType.rectangle
      ..color = 0xFF000000
      ..strokeWidth = 2.0
      ..hasFill = false
      ..fillColor = 0
      ..opacity = 1.0
      ..rotation = 0.0
      ..text = ''
      ..fontSize = 16
      ..fontFamily = 'Roboto'
      ..isBold = false
      ..isItalic = false
      ..svgRelativePath = ''
      ..zOrder = 0
      ..geometryData = [0, 0, 10, 10];

    LassoTransformCommand strokeCommand(
      Stroke original, {
      required Offset center,
      required double scale,
      required Offset translation,
    }) {
      return LassoTransformCommand(
        canvasNotifier: canvas,
        shapeNotifier: shapes,
        center: center,
        scale: scale,
        translation: translation,
        strokeIds: {'s1'},
        shapeIds: const {},
        strokesSnapshot: [original],
        shapesSnapshot: const [],
      );
    }

    test('execute scales + translates strokes around the centre', () {
      final original = makeStroke();
      canvas.loadStrokes([original]);

      strokeCommand(original,
              center: Offset.zero, scale: 2.0, translation: const Offset(10, 5))
          .execute();

      final p = canvasState.completedStrokes.single.points;
      // p' = center + (p - center)*scale + translation
      expect(p[0].x, closeTo(3 * 2 + 10, 1e-9));
      expect(p[0].y, closeTo(4 * 2 + 5, 1e-9));
      expect(p[1].x, closeTo(5 * 2 + 10, 1e-9));
      expect(p[1].y, closeTo(6 * 2 + 5, 1e-9));
      // Stroke width scales with the selection for visual fidelity.
      expect(canvasState.completedStrokes.single.size, closeTo(8.0, 1e-9));
    });

    test('undo restores the exact original stroke', () {
      final original = makeStroke();
      canvas.loadStrokes([original]);

      final command = strokeCommand(original,
          center: Offset.zero, scale: 2.0, translation: const Offset(10, 5));
      command.execute();
      command.undo();

      final restored = canvasState.completedStrokes.single;
      expect(restored.size, 4.0);
      expect(restored.points[0].x, 3);
      expect(restored.points[0].y, 4);
      expect(restored.points[1].x, 5);
      expect(restored.points[1].y, 6);
    });

    test('redo reapplies the same transform deterministically', () {
      final original = makeStroke();
      canvas.loadStrokes([original]);

      final command = strokeCommand(original,
          center: Offset.zero, scale: 3.0, translation: Offset.zero);
      command.execute();
      command.undo();
      command.execute(); // redo

      final p = canvasState.completedStrokes.single.points;
      expect(p[0].x, closeTo(9, 1e-9));
      expect(p[0].y, closeTo(12, 1e-9));
    });

    test('transforms shape geometry and restores on undo', () {
      final rect = makeRect();
      // Seed the notifier state with the shape (memory-only optimistic add).
      shapes.addShape(rect);

      final command = LassoTransformCommand(
        canvasNotifier: canvas,
        shapeNotifier: shapes,
        center: Offset.zero,
        scale: 2.0,
        translation: Offset.zero,
        strokeIds: const {},
        shapeIds: {'r1'},
        strokesSnapshot: const [],
        shapesSnapshot: [rect],
      );

      command.execute();
      expect(shapeState.shapes.single.geometryData, [0, 0, 20, 20]);
      expect(shapeState.shapes.single.strokeWidth, closeTo(4.0, 1e-9));

      command.undo();
      expect(shapeState.shapes.single.geometryData, [0, 0, 10, 10]);
      expect(shapeState.shapes.single.strokeWidth, 2.0);
    });

    test('a pure move (scale == 1) leaves size unchanged', () {
      final original = makeStroke();
      canvas.loadStrokes([original]);

      strokeCommand(original,
              center: const Offset(100, 100),
              scale: 1.0,
              translation: const Offset(7, -3))
          .execute();

      final p = canvasState.completedStrokes.single.points;
      expect(p[0].x, closeTo(10, 1e-9));
      expect(p[0].y, closeTo(1, 1e-9));
      expect(canvasState.completedStrokes.single.size, 4.0);
    });

    test('rotates stroke points about the centre and restores on undo', () {
      final original = makeStroke();
      canvas.loadStrokes([original]);

      final command = LassoTransformCommand(
        canvasNotifier: canvas,
        shapeNotifier: shapes,
        center: Offset.zero,
        rotation: math.pi / 2, // 90°: (x, y) -> (-y, x)
        strokeIds: {'s1'},
        shapeIds: const {},
        strokesSnapshot: [original],
        shapesSnapshot: const [],
      );
      command.execute();

      final p = canvasState.completedStrokes.single.points;
      expect(p[0].x, closeTo(-4, 1e-6));
      expect(p[0].y, closeTo(3, 1e-6));
      expect(p[1].x, closeTo(-6, 1e-6));
      expect(p[1].y, closeTo(5, 1e-6));
      // A pure rotation leaves the stroke width unchanged.
      expect(canvasState.completedStrokes.single.size, closeTo(4.0, 1e-9));

      command.undo();
      final r = canvasState.completedStrokes.single.points;
      expect(r[0].x, 3);
      expect(r[0].y, 4);
      expect(r[1].x, 5);
      expect(r[1].y, 6);
    });

    test('rotates a shape via its rotation field, keeping geometry rigid', () {
      final rect = makeRect(); // [0,0,10,10], centre (5,5)
      shapes.addShape(rect);

      final command = LassoTransformCommand(
        canvasNotifier: canvas,
        shapeNotifier: shapes,
        center: const Offset(5, 5), // rotate about the shape's own centre
        rotation: math.pi / 2,
        strokeIds: const {},
        shapeIds: {'r1'},
        strokesSnapshot: const [],
        shapesSnapshot: [rect],
      );
      command.execute();

      final s = shapeState.shapes.single;
      expect(s.rotation, closeTo(math.pi / 2, 1e-6));
      // Rotating about its own centre re-centres to the same point -> geometry
      // is unchanged; the rotation lives in the rotation field.
      expect(s.geometryData, [0, 0, 10, 10]);

      command.undo();
      expect(shapeState.shapes.single.rotation, 0.0);
      expect(shapeState.shapes.single.geometryData, [0, 0, 10, 10]);
    });
  });
}
