import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/geometry/scene_hit_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';

SceneShapeElement _rect(String id, int z, List<double> g, {bool locked = false}) =>
    SceneShapeElement(
      id: id,
      zOrder: z,
      shapeType: ShapeType.rectangle,
      geometryData: g,
      color: 0xFF000000,
      strokeWidth: 2,
      isLocked: locked,
    );

void main() {
  test('topmostAt returns the highest zOrder element under the point', () {
    final els = [
      _rect('a', 0, [0, 0, 20, 20]),
      _rect('b', 1, [0, 0, 20, 20]),
    ];
    expect(SceneHitTest.topmostAt(const Offset(10, 10), els), 'b');
  });

  test('topmostAt skips locked elements by default', () {
    final els = [
      _rect('a', 0, [0, 0, 20, 20]),
      _rect('b', 1, [0, 0, 20, 20], locked: true),
    ];
    expect(SceneHitTest.topmostAt(const Offset(10, 10), els), 'a');
  });

  test('topmostAt returns null when nothing is hit', () {
    final els = [_rect('a', 0, [0, 0, 20, 20])];
    expect(SceneHitTest.topmostAt(const Offset(100, 100), els), isNull);
  });

  test('within returns all elements intersecting the marquee', () {
    final els = [
      _rect('a', 0, [0, 0, 20, 20]),
      _rect('b', 1, [100, 100, 120, 120]),
    ];
    final hit = SceneHitTest.within(const Rect.fromLTRB(-5, -5, 30, 30), els);
    expect(hit, ['a']);
    final both = SceneHitTest.within(const Rect.fromLTRB(-5, -5, 200, 200), els);
    expect(both.toSet(), {'a', 'b'});
  });
}
