// Smoke test: every element kind paints without throwing (covers the rough,
// fill-style, stroke-style, arrowhead, text and image code paths).

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/render/scene_element_painter.dart';

void main() {
  test('paints all element kinds without error', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);

    const container = SceneShapeElement(
      id: 'box',
      zOrder: 0,
      shapeType: ShapeType.rectangle,
      geometryData: [0, 0, 100, 60],
      color: 0xFF000000,
      strokeWidth: 2,
      hasFill: true,
      fillColor: 0xFFFFE066,
      fillStyle: FillStyle.crossHatch,
      edges: EdgeStyle.round,
      strokeStyle: StrokeStyle.dashed,
    );

    final elements = <SceneElement>[
      const FreehandElement(
        id: 'f',
        zOrder: 0,
        color: 0xFF000000,
        size: 3,
        points: [StrokePoint(x: 0, y: 0), StrokePoint(x: 10, y: 10)],
      ),
      container,
      const SceneShapeElement(
        id: 'ell',
        zOrder: 1,
        shapeType: ShapeType.circle,
        geometryData: [0, 0, 40, 40],
        color: 0xFF000000,
        strokeWidth: 2,
        roughness: 1.5,
        hasFill: true,
        fillColor: 0xFFAACCEE,
      ),
      const SceneShapeElement(
        id: 'arr',
        zOrder: 2,
        shapeType: ShapeType.arrow,
        geometryData: [0, 0, 50, 30],
        color: 0xFF000000,
        strokeWidth: 2,
        endArrowhead: Arrowhead.triangle,
        elbowed: true,
      ),
      const TextElement(
        id: 't',
        zOrder: 3,
        geometryData: [0, 0, 120, 30],
        text: 'bound',
        color: 0xFF000000,
        containerId: 'box',
      ),
      const ImageElement(
        id: 'img',
        zOrder: 4,
        geometryData: [0, 0, 80, 80],
        relativeImagePath: 'x.png',
        sourceDescription: 'pic',
      ),
    ];

    final byId = {for (final e in elements) e.id: e};
    expect(() {
      for (final e in elements) {
        SceneElementPainter.paint(canvas, e, byId: byId);
      }
      recorder.endRecording();
    }, returnsNormally);
  });
}
