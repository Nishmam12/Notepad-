import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/shape_element.dart';
import 'package:inkflow/features/editor/domain/services/shape_hit_tester.dart';

void main() {
  group('ShapeHitTester', () {
    test('hits a line when the point is on it', () {
      final line = ShapeElement.line(
        id: 'l',
        start: const Offset(0, 0),
        end: const Offset(100, 0),
        color: 0xFF000000,
        strokeWidth: 4,
      );
      expect(ShapeHitTester.isHit(line, const Offset(50, 1), 5), isTrue);
      expect(ShapeHitTester.isHit(line, const Offset(50, 40), 5), isFalse);
    });

    test('hits a rectangle outline but not its empty interior', () {
      final rect = ShapeElement.rectangle(
        id: 'r',
        rect: const Rect.fromLTRB(0, 0, 100, 100),
        color: 0xFF000000,
        strokeWidth: 4,
      );
      // Near the top edge.
      expect(ShapeHitTester.isHit(rect, const Offset(50, 2), 5), isTrue);
      // Dead centre of an unfilled rect is not a hit.
      expect(ShapeHitTester.isHit(rect, const Offset(50, 50), 5), isFalse);
    });

    test('hits anywhere inside a filled rectangle', () {
      final rect = ShapeElement.rectangle(
        id: 'r',
        rect: const Rect.fromLTRB(0, 0, 100, 100),
        color: 0xFF000000,
        strokeWidth: 4,
        hasFill: true,
        fillColor: 0xFF000000,
      );
      expect(ShapeHitTester.isHit(rect, const Offset(50, 50), 5), isTrue);
    });

    test('hits a circle on its outline but not its centre', () {
      final circle = ShapeElement.circle(
        id: 'c',
        rect: const Rect.fromLTRB(0, 0, 100, 100),
        color: 0xFF000000,
        strokeWidth: 4,
      );
      // Right edge of the ellipse.
      expect(ShapeHitTester.isHit(circle, const Offset(100, 50), 6), isTrue);
      // Centre of an unfilled circle is not a hit.
      expect(ShapeHitTester.isHit(circle, const Offset(50, 50), 5), isFalse);
    });

    test('hits a text box anywhere inside its body', () {
      final textBox = ShapeElement.textBox(
        id: 't',
        rect: const Rect.fromLTRB(0, 0, 200, 50),
        color: 0xFF000000,
        text: 'hello',
        fontSize: 16,
      );
      expect(ShapeHitTester.isHit(textBox, const Offset(100, 25), 5), isTrue);
      expect(ShapeHitTester.isHit(textBox, const Offset(400, 25), 5), isFalse);
    });
  });
}
