import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/stroke.dart';
import 'package:inkflow/features/editor/domain/models/stroke_point.dart';
import 'package:inkflow/features/editor/domain/services/eraser_service.dart';

void main() {
  Stroke vertical(String id, double x, {double size = 4}) => Stroke(
        id: id,
        color: 0xFF000000,
        size: size,
        opacity: 1.0,
        isEraser: false,
        points: [
          StrokePoint(x: x, y: 40, pressure: 0.5),
          StrokePoint(x: x, y: 60, pressure: 0.5),
        ],
      );

  group('EraserService.hitAlongSegment', () {
    test('a fast swipe (one long segment) catches every stroke it crosses', () {
      // The eraser only has two sample points (0,50)->(100,50) but the segment
      // crosses two far-apart vertical strokes; both must be erased.
      final result = EraserService.hitAlongSegment(
        a: const Offset(0, 50),
        b: const Offset(100, 50),
        radius: 2,
        strokes: [vertical('a', 20), vertical('b', 80)],
        shapes: const [],
      );
      expect(result.$1, {'a', 'b'});
    });

    test('is width-aware: a thick stroke erases from its visible edge', () {
      // Centerline is 8px from the eraser line. radius=2.
      const thick = Stroke(
        id: 'thick',
        color: 0xFF000000,
        size: 20, // tol = 2 + 10 = 12 >= 8 -> hit
        opacity: 1.0,
        isEraser: false,
        points: [
          StrokePoint(x: 0, y: 58, pressure: 0.5),
          StrokePoint(x: 100, y: 58, pressure: 0.5),
        ],
      );
      final thin = thick.copyWith(id: 'thin', size: 4); // tol = 4 < 8 -> miss

      final hitThick = EraserService.hitAlongSegment(
        a: const Offset(0, 50),
        b: const Offset(100, 50),
        radius: 2,
        strokes: [thick],
        shapes: const [],
      );
      final hitThin = EraserService.hitAlongSegment(
        a: const Offset(0, 50),
        b: const Offset(100, 50),
        radius: 2,
        strokes: [thin],
        shapes: const [],
      );

      expect(hitThick.$1, contains('thick'));
      expect(hitThin.$1, isEmpty);
    });

    test('ignores eraser strokes and already-pending ids', () {
      final eraserStroke = vertical('e', 20).copyWith(isEraser: true);
      final result = EraserService.hitAlongSegment(
        a: const Offset(0, 50),
        b: const Offset(100, 50),
        radius: 2,
        strokes: [eraserStroke, vertical('b', 80)],
        shapes: const [],
        skipStrokeIds: const {'b'},
      );
      expect(result.$1, isEmpty); // 'e' is an eraser, 'b' is skipped
    });
  });
}
