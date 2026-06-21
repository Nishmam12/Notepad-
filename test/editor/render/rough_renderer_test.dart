import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/editor/render/rough_renderer.dart';

void main() {
  const pts = [Offset(0, 0), Offset(10, 0), Offset(5, 10)];

  test('outline is deterministic for the same seed', () {
    final a = RoughRenderer.outline(pts, true, 42, 1.5);
    final b = RoughRenderer.outline(pts, true, 42, 1.5);
    expect(a.getBounds(), b.getBounds());
  });

  test('outline differs for a different seed', () {
    final a = RoughRenderer.outline(pts, true, 42, 1.5);
    final b = RoughRenderer.outline(pts, true, 7, 1.5);
    expect(a.getBounds(), isNot(b.getBounds()));
  });

  test('ellipsePolygon has the requested number of points', () {
    final poly = RoughRenderer.ellipsePolygon(const Rect.fromLTRB(0, 0, 20, 10), 24);
    expect(poly.length, 24);
  });
}
