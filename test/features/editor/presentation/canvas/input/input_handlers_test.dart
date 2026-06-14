import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/shape_element.dart';
import 'package:inkflow/features/editor/domain/models/shape_type.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/editor/presentation/canvas_notifier.dart';
import 'package:inkflow/features/editor/presentation/canvas/input/shape_input_handler.dart';
import 'package:inkflow/features/editor/presentation/canvas/input/lasso_input_handler.dart';

void main() {
  // Handlers now accept StrokePoint / Offset (scene-space coordinates) directly,
  // so there is no PointerEvent cast risk. These tests verify that the handlers
  // complete normally and produce the expected output.
  group('Input handlers accept scene-space coordinates', () {
    test('ShapeInputHandler.onPointerUp finalises a shape from StrokePoints', () {
      ShapeElement? recognised;
      final handler = ShapeInputHandler(
        onShapeRecognised: (s) => recognised = s,
        onShapeFallback: (_) {},
        getToolState: () => const ToolState(),
      );

      handler.onPointerDown(const StrokePoint(x: 0, y: 0));
      handler.onPointerMove(const StrokePoint(x: 60, y: 60));

      expect(
        () => handler.onPointerUp(const StrokePoint(x: 60, y: 60)),
        returnsNormally,
      );
      // A line shape was finalised from the gesture.
      expect(recognised, isNotNull);
    });

    test('LassoInputHandler.onPointerUp with fewer than 3 points returns normally', () {
      final handler = LassoInputHandler(
        onLassoComplete: (_, __) {},
        onLassoUpdate: (_) {},
        getCurrentStrokes: () => const [],
        getCurrentShapes: () => const [],
      );

      handler.onPointerDown(const Offset(0, 0));

      expect(
        () => handler.onPointerUp(const Offset(0, 0)),
        returnsNormally,
      );
    });

    test('ShapeInputHandler emits a live preview shape via onPreviewUpdate', () {
      final previews = <ShapeElement?>[];
      final handler = ShapeInputHandler(
        onShapeRecognised: (_) {},
        onShapeFallback: (_) {},
        getToolState: () => const ToolState(),
        onPreviewUpdate: previews.add,
      );

      handler.onPointerDown(const StrokePoint(x: 0, y: 0));
      handler.onPointerMove(const StrokePoint(x: 60, y: 60));

      // A preview shape is produced once there are enough drag points.
      expect(previews.isNotEmpty, isTrue);
      expect(previews.last, isNotNull);

      // Ending the gesture clears the preview.
      handler.onPointerUp(const StrokePoint(x: 60, y: 60));
      expect(previews.last, isNull);
    });

    test('shape can be shrunk mid-drag by moving back toward the start', () {
      ShapeElement? recognised;
      final handler = ShapeInputHandler(
        onShapeRecognised: (s) => recognised = s,
        onShapeFallback: (_) {},
        getToolState: () => const ToolState(selectedShapeType: ShapeType.rectangle),
      );

      // Drag far out, then back in toward the start point.
      handler.onPointerDown(const StrokePoint(x: 0, y: 0));
      handler.onPointerMove(const StrokePoint(x: 100, y: 100));
      handler.onPointerMove(const StrokePoint(x: 20, y: 20));
      handler.onPointerUp(const StrokePoint(x: 20, y: 20));

      // The shape is sized from start -> current point, not the max extent,
      // so the final rectangle is 20x20, not 100x100.
      expect(recognised, isNotNull);
      // geometryData for a rectangle is [left, top, right, bottom].
      expect(recognised!.geometryData, [0.0, 0.0, 20.0, 20.0]);
    });
  });
}
