import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/render/scene_exporter.dart';

const _scene = <SceneElement>[
  SceneShapeElement(
    id: 'r',
    zOrder: 0,
    shapeType: ShapeType.rectangle,
    geometryData: [0, 0, 100, 100],
    color: 0xFF112233,
    strokeWidth: 2,
  ),
  TextElement(
    id: 't',
    zOrder: 1,
    geometryData: [10, 10, 90, 30],
    text: 'Hi',
    color: 0xFF000000,
    fontSize: 16,
  ),
  FreehandElement(
    id: 'f',
    zOrder: 2,
    color: 0xFF000000,
    size: 3,
    points: [
      StrokePoint(x: 5, y: 5, pressure: 0.5),
      StrokePoint(x: 25, y: 25, pressure: 0.5),
      StrokePoint(x: 45, y: 5, pressure: 0.5),
    ],
  ),
  FrameElement(
    id: 'fr',
    zOrder: 3,
    geometryData: [0, 0, 120, 120],
    name: 'Sketch',
  ),
];

void main() {
  test('contentBounds is the padded union, null when empty', () {
    expect(SceneExporter.contentBounds(const []), isNull);
    final b = SceneExporter.contentBounds(_scene, padding: 10)!;
    expect(b.left, -10);
    expect(b.top, -10);
    expect(b.right, 130); // frame extends to 120 + 10
    expect(b.bottom, 130);
  });

  test('toSvg emits a vector element per scene element', () {
    final svg = SceneExporter.toSvg(_scene);
    expect(svg, contains('<svg'));
    expect(svg, contains('viewBox='));
    expect(svg, contains('<rect')); // rectangle + frame
    expect(svg, contains('<text')); // text + frame label
    expect(svg, contains('Hi'));
    expect(svg, contains('Sketch'));
    expect(svg, contains('<polyline')); // freehand
    expect(svg, contains('#112233')); // stroke colour preserved
  });

  test('toSvg escapes XML-special characters in text', () {
    const els = [
      TextElement(
        id: 't',
        zOrder: 0,
        geometryData: [0, 0, 100, 20],
        text: 'a < b & "c"',
        color: 0xFF000000,
        fontSize: 12,
      ),
    ];
    final svg = SceneExporter.toSvg(els);
    expect(svg, contains('a &lt; b &amp; &quot;c&quot;'));
    expect(svg, isNot(contains('a < b &')));
  });

  testWidgets('toPng produces PNG bytes; toPdf produces a PDF', (tester) async {
    await tester.runAsync(() async {
      final png = await SceneExporter.toPng(_scene, scale: 1);
      expect(png, isNotNull);
      // PNG magic number.
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);

      final pdf = await SceneExporter.toPdf(_scene, scale: 1);
      expect(pdf, isNotNull);
      // "%PDF" header.
      expect(String.fromCharCodes(pdf!.sublist(0, 4)), '%PDF');
    });
  });

  testWidgets('export of an empty scene returns null', (tester) async {
    await tester.runAsync(() async {
      expect(await SceneExporter.toPng(const []), isNull);
      expect(await SceneExporter.toPdf(const []), isNull);
    });
  });

  testWidgets('toPng renders a real bitmap when a resolver is supplied',
      (tester) async {
    await tester.runAsync(() async {
      // A real engine image via the supported picture.toImage path.
      final rec = PictureRecorder();
      Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 8, 8),
          Paint()..color = const Color(0xFF00FF00));
      final bitmap = await rec.endRecording().toImage(8, 8);

      const els = [
        ImageElement(
          id: 'i',
          zOrder: 0,
          geometryData: [0, 0, 50, 50],
          relativeImagePath: 'pic.png',
        ),
      ];
      final png = await SceneExporter.toPng(els,
          scale: 1, imageResolver: (p) => p == 'pic.png' ? bitmap : null);
      expect(png, isNotNull);
      expect(png!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
      bitmap.dispose();
    });
  });
}
