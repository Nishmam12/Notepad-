import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/shape_element.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/editor/presentation/canvas_notifier.dart';
import 'package:inkflow/features/editor/presentation/canvas/input/shape_input_handler.dart';
import 'package:inkflow/features/editor/presentation/canvas/input/lasso_input_handler.dart';

void main() {
  // Regression for BUG-1: pointer events are now typed as PointerEvent, so a
  // PointerCancelEvent (delivered via Listener.onPointerCancel → onPointerUp)
  // must not throw a cast error.
  group('Input handlers tolerate PointerCancelEvent', () {
    test('ShapeInputHandler.onPointerUp accepts a cancel event', () {
      ShapeElement? recognised;
      final handler = ShapeInputHandler(
        onShapeRecognised: (s) => recognised = s,
        onShapeFallback: (_) {},
        getToolState: () => const ToolState(),
      );

      handler.onPointerDown(const PointerDownEvent(position: Offset(0, 0)));
      handler.onPointerMove(const PointerMoveEvent(position: Offset(60, 60)));

      expect(
        () => handler.onPointerUp(const PointerCancelEvent(position: Offset(60, 60))),
        returnsNormally,
      );
      // A line shape was finalized from the cancelled gesture.
      expect(recognised, isNotNull);
    });

    test('LassoInputHandler.onPointerUp accepts a cancel event', () {
      final handler = LassoInputHandler(
        onLassoComplete: (_, __) {},
        onLassoUpdate: (_) {},
        getCurrentStrokes: () => const [],
        getCurrentShapes: () => const [],
      );

      handler.onPointerDown(const PointerDownEvent(position: Offset(0, 0)));

      // Fewer than 3 points → early return (no isolate work); just assert the
      // cancel event does not throw.
      expect(
        () => handler.onPointerUp(const PointerCancelEvent(position: Offset(0, 0))),
        returnsNormally,
      );
    });

    test('ShapeInputHandler still records points from base PointerEvents', () {
      final added = <StrokePoint>[];
      final handler = ShapeInputHandler(
        onShapeRecognised: (_) {},
        onShapeFallback: (_) {},
        getToolState: () => const ToolState(),
        onPreviewPointAdd: added.add,
      );

      handler.onPointerDown(const PointerDownEvent(position: Offset(1, 2)));
      handler.onPointerMove(const PointerMoveEvent(position: Offset(3, 4)));

      expect(added.length, 2);
      expect(added.first.x, 1);
      expect(added.first.y, 2);
    });
  });
}
