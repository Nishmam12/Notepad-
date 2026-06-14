import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/shape_element.dart';
import 'package:inkflow/features/editor/domain/models/stroke.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/editor/domain/services/lasso_hit_tester.dart';

void main() {
  group('testLasso', () {
    // A square lasso loop covering [from, to].
    List<Offset> square(Offset from, Offset to) => [
          from,
          Offset(to.dx, from.dy),
          to,
          Offset(from.dx, to.dy),
        ];

    test('selects a text box when the lasso wraps only its visible left edge', () {
      // 200px-wide text box; its centre (100, 25) sits well to the right of any
      // short visible text near the left edge.
      final textBox = ShapeElement.textBox(
        id: 't',
        rect: const Rect.fromLTRB(0, 0, 200, 50),
        color: 0xFF000000,
        text: 'Hi',
        fontSize: 16,
      );

      // Loop tightly around the top-left corner only — excludes the centre.
      final result = testLasso(
        lassoPath: square(const Offset(-10, -10), const Offset(30, 40)),
        strokes: const [],
        shapes: [textBox],
      );

      expect(result.selectedShapeIds, contains('t'));
    });

    test('does not select a text box the lasso misses entirely', () {
      final textBox = ShapeElement.textBox(
        id: 't',
        rect: const Rect.fromLTRB(0, 0, 200, 50),
        color: 0xFF000000,
        text: 'Hi',
        fontSize: 16,
      );

      final result = testLasso(
        lassoPath: square(const Offset(300, 300), const Offset(400, 400)),
        strokes: const [],
        shapes: [textBox],
      );

      expect(result.selectedShapeIds, isEmpty);
    });

    test('selects a stroke when any of its points is inside the lasso', () {
      const stroke = Stroke(
        id: 's',
        color: 0xFF000000,
        size: 4,
        opacity: 1,
        isEraser: false,
        points: [
          StrokePoint(x: 10, y: 10),
          StrokePoint(x: 500, y: 500),
        ],
      );

      final result = testLasso(
        lassoPath: square(const Offset(0, 0), const Offset(50, 50)),
        strokes: [stroke],
        shapes: const [],
      );

      expect(result.selectedStrokeIds, contains('s'));
    });
  });
}
