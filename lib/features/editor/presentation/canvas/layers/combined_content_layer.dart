// Combined content layer — draws completed strokes AND vector shapes inside a
// single saveLayer so that eraser strokes (BlendMode.clear) clear *both* of them.
//
// This is what makes the pixel eraser able to erase shapes as well as ink: all
// drawable content is composited into one offscreen layer, replayed in
// chronological order, and eraser strokes (committed or the live in-progress
// one) punch transparent holes through everything drawn before them.

import 'dart:math' show sin, pi;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../../domain/models/stroke.dart';
import '../../../domain/models/stroke_point.dart' as models;
import '../../../domain/models/shape_element.dart';
import '../../../domain/models/shape_type.dart';
import '../../../domain/services/shape_geometry.dart';
import '../../selection_notifier.dart';

/// Caches generated freehand paths per Stroke object. A stroke moved/scaled is a
/// new object (via copyWith), so it misses the cache and recomputes at its new
/// geometry; superseded strokes are GC'd along with their cached path.
final Expando<Path> _strokePathCache = Expando<Path>();

/// Cached base picture (all unselected strokes + shapes, in chronological order).
/// Rebuilt only when the content set or selection changes — so a live pixel-erase
/// drag reuses it and just re-clears the active path each frame.
class CombinedContentCache {
  static ui.Picture? picture;
  static int pageIndex = -1;
  static List<Stroke>? strokes;
  static List<ShapeElement>? shapes;
  static Set<String> selectedStrokeIds = const {};
  static Set<String> selectedShapeIds = const {};

  static void invalidate() {
    picture?.dispose();
    picture = null;
    pageIndex = -1;
    strokes = null;
    shapes = null;
  }
}

class CombinedContentLayer extends CustomPainter {
  final List<Stroke> strokes;
  final List<ShapeElement> shapes;
  final ShapeElement? previewShape;
  final SelectionState selectionState;
  final int pageIndex;

  // Live in-progress pixel-eraser stroke (empty unless actively erasing).
  final List<models.StrokePoint> activeEraserPoints;
  final double activeEraserSize;
  final bool isErasing;

  const CombinedContentLayer({
    required this.strokes,
    required this.shapes,
    required this.selectionState,
    required this.pageIndex,
    this.previewShape,
    this.activeEraserPoints = const [],
    this.activeEraserSize = 4.0,
    this.isErasing = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    _ensureBasePicture(size);
    if (CombinedContentCache.picture != null) {
      canvas.drawPicture(CombinedContentCache.picture!);
    }

    // Live pixel-erase: punch a transparent hole through the composited content.
    if (isErasing && activeEraserPoints.isNotEmpty) {
      final path = _strokeOutline(activeEraserPoints, activeEraserSize,
          isComplete: false);
      if (path != null) {
        canvas.drawPath(
          path,
          Paint()
            ..blendMode = BlendMode.clear
            ..style = PaintingStyle.fill,
        );
      }
    }

    // Preview shape (drawn during a shape drag) sits on top, never erased.
    if (previewShape != null) {
      _drawShape(canvas, previewShape!);
    }

    // Selected strokes/shapes are excluded from the cached base and drawn here
    // with the live transform applied, so they move/scale smoothly.
    _drawSelectedTransformed(canvas);

    canvas.restore();
  }

  void _ensureBasePicture(Size size) {
    final selStrokes = selectionState.selectedStrokeIds;
    final selShapes = selectionState.selectedShapeIds;

    final needsRebuild = CombinedContentCache.picture == null ||
        CombinedContentCache.pageIndex != pageIndex ||
        !identical(CombinedContentCache.strokes, strokes) ||
        !identical(CombinedContentCache.shapes, shapes) ||
        !setEquals(CombinedContentCache.selectedStrokeIds, selStrokes) ||
        !setEquals(CombinedContentCache.selectedShapeIds, selShapes);

    if (!needsRebuild) return;

    CombinedContentCache.picture?.dispose();

    final recorder = ui.PictureRecorder();
    final recordCanvas = Canvas(recorder);

    for (final item in _chronologicalItems(selStrokes, selShapes)) {
      if (item.stroke != null) {
        _drawStroke(recordCanvas, item.stroke!);
      } else if (item.shape != null) {
        _drawShape(recordCanvas, item.shape!);
      }
    }

    CombinedContentCache.picture = recorder.endRecording();
    CombinedContentCache.pageIndex = pageIndex;
    CombinedContentCache.strokes = strokes;
    CombinedContentCache.shapes = shapes;
    CombinedContentCache.selectedStrokeIds = selStrokes;
    CombinedContentCache.selectedShapeIds = selShapes;
  }

  /// Merges unselected strokes and shapes into a single list ordered by creation
  /// time, so eraser strokes clear everything (ink + shapes) drawn before them.
  List<_Drawable> _chronologicalItems(
      Set<String> selStrokes, Set<String> selShapes) {
    final items = <_Drawable>[];
    int seq = 0;
    for (final s in strokes) {
      if (selStrokes.contains(s.id)) continue;
      items.add(_Drawable(int.tryParse(s.id) ?? 0, seq++, stroke: s));
    }
    for (final sh in shapes) {
      if (selShapes.contains(sh.id)) continue;
      // zOrder is in milliseconds; strokes use microseconds — normalise to µs.
      items.add(_Drawable(sh.zOrder * 1000, seq++, shape: sh));
    }
    items.sort((a, b) {
      final c = a.orderKey.compareTo(b.orderKey);
      return c != 0 ? c : a.seq.compareTo(b.seq);
    });
    return items;
  }

  void _drawSelectedTransformed(Canvas canvas) {
    final selStrokes = selectionState.selectedStrokeIds;
    final selShapes = selectionState.selectedShapeIds;
    if (selStrokes.isEmpty && selShapes.isEmpty) return;

    final transforming = selectionState.isTransforming;

    void withTransform(VoidCallback draw) {
      if (transforming) {
        canvas.save();
        canvas.translate(selectionState.currentTranslation.dx,
            selectionState.currentTranslation.dy);
        if (selectionState.currentScale != 1.0 &&
            selectionState.selectionBounds != null) {
          final center = selectionState.selectionBounds!.center;
          canvas.translate(center.dx, center.dy);
          canvas.scale(selectionState.currentScale);
          canvas.translate(-center.dx, -center.dy);
        }
      }
      draw();
      if (transforming) canvas.restore();
    }

    for (final s in strokes) {
      if (selStrokes.contains(s.id)) {
        withTransform(() => _drawStroke(canvas, s));
      }
    }
    for (final sh in shapes) {
      if (selShapes.contains(sh.id)) {
        withTransform(() => _drawShape(canvas, sh));
      }
    }
  }

  // ---- Stroke rendering -----------------------------------------------------

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser
          ? Colors.transparent
          : Color(stroke.color).withValues(alpha: stroke.opacity)
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
      ..style = PaintingStyle.fill;

    Path? path = _strokePathCache[stroke];
    if (path == null) {
      path = _strokeOutline(stroke.points, stroke.size, isComplete: true);
      if (path == null) return;
      _strokePathCache[stroke] = path;
    }

    canvas.drawPath(path, paint);
  }

  Path? _strokeOutline(List<models.StrokePoint> pts, double size,
      {required bool isComplete}) {
    final inputPoints =
        pts.map((p) => PointVector(p.x, p.y, p.pressure)).toList();
    if (inputPoints.isEmpty) return null;

    final simulate = pts.first.simulatePressure;
    final outlinePoints = getStroke(
      inputPoints,
      options: StrokeOptions(
        size: size,
        thinning: 0.6,
        smoothing: 0.5,
        streamline: 0.5,
        easing: (t) => sin(t * pi / 2),
        simulatePressure: simulate,
        isComplete: isComplete,
      ),
    );
    if (outlinePoints.isEmpty) return null;
    return _buildPath(outlinePoints);
  }

  Path _buildPath(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      final midY = (p0.dy + p1.dy) / 2;
      path.quadraticBezierTo(p0.dx, p0.dy, midX, midY);
    }
    if (points.length > 1) {
      path.lineTo(points.last.dx, points.last.dy);
    }
    path.close();
    return path;
  }

  // ---- Shape rendering (mirrors ShapeLayer) ---------------------------------

  void _drawShape(Canvas canvas, ShapeElement shape) {
    canvas.save();
    final centre = _shapeCentre(shape);
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(shape.rotation);
    canvas.translate(-centre.dx, -centre.dy);

    final strokePaint = Paint()
      ..color = Color(shape.color).withValues(alpha: shape.opacity)
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Color(shape.fillColor)
          .withValues(alpha: shape.hasFill ? shape.opacity : 0)
      ..style = PaintingStyle.fill;

    switch (shape.type) {
      case ShapeType.line:
        final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
        canvas.drawLine(start, end, strokePaint);
        break;

      case ShapeType.arrow:
        final start = Offset(shape.geometryData[0], shape.geometryData[1]);
        final end = Offset(shape.geometryData[2], shape.geometryData[3]);
        canvas.drawLine(start, end, strokePaint);
        if (shape.geometryData.length >= 8) {
          final arrowPath = Path()
            ..moveTo(shape.geometryData[4], shape.geometryData[5])
            ..lineTo(end.dx, end.dy)
            ..lineTo(shape.geometryData[6], shape.geometryData[7])
            ..close();
          canvas.drawPath(arrowPath, strokePaint..style = PaintingStyle.fill);
        }
        break;

      case ShapeType.circle:
        final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
        if (shape.hasFill) canvas.drawOval(rect, fillPaint);
        canvas.drawOval(rect, strokePaint);
        break;

      case ShapeType.rectangle:
        final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
        if (shape.hasFill) canvas.drawRect(rect, fillPaint);
        canvas.drawRect(rect, strokePaint);
        break;

      case ShapeType.triangle:
      case ShapeType.polygon:
      case ShapeType.diamond:
        final vertices = ShapeGeometry.verticesFromGeometry(shape.geometryData);
        if (vertices.isNotEmpty) {
          final path = Path()..addPolygon(vertices, true);
          if (shape.hasFill) canvas.drawPath(path, fillPaint);
          canvas.drawPath(path, strokePaint);
        }
        break;

      case ShapeType.textBox:
        _drawTextBox(canvas, shape);
        break;

      case ShapeType.svgImage:
        final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
        canvas.drawRect(rect,
            strokePaint..color = strokePaint.color.withValues(alpha: 0.4));
        break;
    }

    canvas.restore();
  }

  void _drawTextBox(Canvas canvas, ShapeElement shape) {
    final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: shape.fontSize,
        fontFamily: shape.fontFamily,
        fontWeight: shape.isBold ? FontWeight.bold : FontWeight.normal,
        fontStyle: shape.isItalic ? FontStyle.italic : FontStyle.normal,
      ),
    )
      ..pushStyle(ui.TextStyle(
          color: Color(shape.color).withValues(alpha: shape.opacity)))
      ..addText(shape.text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));
    canvas.drawParagraph(paragraph, rect.topLeft);
  }

  Offset _shapeCentre(ShapeElement shape) {
    if (shape.type == ShapeType.circle ||
        shape.type == ShapeType.rectangle ||
        shape.type == ShapeType.textBox ||
        shape.type == ShapeType.svgImage) {
      return ShapeGeometry.rectFromGeometry(shape.geometryData).center;
    } else if (shape.type == ShapeType.line || shape.type == ShapeType.arrow) {
      final (start, end) = ShapeGeometry.lineFromGeometry(shape.geometryData);
      return Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
    }

    final verts = ShapeGeometry.verticesFromGeometry(shape.geometryData);
    if (verts.isEmpty) {
      if (shape.geometryData.length >= 2) {
        return Offset(shape.geometryData[0], shape.geometryData[1]);
      }
      return Offset.zero;
    }
    return ShapeGeometry.centroid(verts);
  }

  @override
  bool shouldRepaint(CombinedContentLayer oldDelegate) =>
      strokes != oldDelegate.strokes ||
      shapes != oldDelegate.shapes ||
      previewShape != oldDelegate.previewShape ||
      selectionState != oldDelegate.selectionState ||
      pageIndex != oldDelegate.pageIndex ||
      isErasing != oldDelegate.isErasing ||
      activeEraserPoints != oldDelegate.activeEraserPoints ||
      activeEraserSize != oldDelegate.activeEraserSize;
}

class _Drawable {
  final int orderKey;
  final int seq;
  final Stroke? stroke;
  final ShapeElement? shape;
  _Drawable(this.orderKey, this.seq, {this.stroke, this.shape});
}
