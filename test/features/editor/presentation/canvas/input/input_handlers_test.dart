import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/shape_element.dart';
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

    test('ShapeInputHandler records StrokePoint positions via onPreviewPointAdd', () {
      final added = <StrokePoint>[];
      final handler = ShapeInputHandler(
        onShapeRecognised: (_) {},
        onShapeFallback: (_) {},
        getToolState: () => const ToolState(),
        onPreviewPointAdd: added.add,
      );

      handler.onPointerDown(const StrokePoint(x: 1, y: 2));
      handler.onPointerMove(const StrokePoint(x: 3, y: 4));

      expect(added.length, 2);
      expect(added.first.x, 1);
      expect(added.first.y, 2);
    });
  });
}
