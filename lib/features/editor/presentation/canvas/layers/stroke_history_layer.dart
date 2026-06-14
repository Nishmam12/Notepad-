// Stroke history layer — draws all completed strokes using perfect_freehand.

import 'package:flutter/material.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import 'dart:ui' as ui;

import '../../../domain/models/stroke.dart';
import '../../selection_notifier.dart';

// A cache for generated paths to prevent recalculating `perfect_freehand` every
// frame. Keyed by the Stroke *object* (not its id) via an Expando: a stroke that
// is moved/scaled is a new object produced by copyWith, so it misses the cache
// and its path is recomputed at the new geometry. Superseded strokes are GC'd
// along with their cached path, so the cache cannot grow unbounded.
final Expando<Path> _pathCache = Expando<Path>();

class StrokePictureCache {
  static ui.Picture? picture;
  static int strokeCount = 0;
  static int pageIndex = -1;
  static Set<String> excludedIds = {};

  static void invalidate() {
    picture?.dispose();
    picture = null;
    strokeCount = 0;
    excludedIds = {};
  }
}

class StrokeHistoryLayer extends CustomPainter {
  final List<Stroke> strokes;
  final SelectionState selectionState;
  final int pageIndex;

  const StrokeHistoryLayer({
    required this.strokes,
    required this.selectionState,
    required this.pageIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    final selectedIds = selectionState.selectedStrokeIds;
    final unselectedStrokes = strokes.where((s) => !selectedIds.contains(s.id)).toList();

    // Check if we need a full rebuild of the picture
    bool needsFullRebuild = StrokePictureCache.picture == null || 
                            StrokePictureCache.pageIndex != pageIndex ||
                            StrokePictureCache.strokeCount > unselectedStrokes.length ||
                            !StrokePictureCache.excludedIds.containsAll(selectedIds) ||
                            StrokePictureCache.excludedIds.length != selectedIds.length;

    if (needsFullRebuild) {
      StrokePictureCache.invalidate();
      final recorder = ui.PictureRecorder();
      final recordCanvas = Canvas(recorder);
      
      for (final stroke in unselectedStrokes) {
        _drawStroke(recordCanvas, stroke);
      }
      
      StrokePictureCache.picture = recorder.endRecording();
      StrokePictureCache.strokeCount = unselectedStrokes.length;
      StrokePictureCache.pageIndex = pageIndex;
      StrokePictureCache.excludedIds = Set.from(selectedIds);
    } else if (StrokePictureCache.strokeCount < unselectedStrokes.length) {
      // Incremental build: just append the new unselected strokes!
      final recorder = ui.PictureRecorder();
      final recordCanvas = Canvas(recorder);
      
      recordCanvas.drawPicture(StrokePictureCache.picture!);
      
      for (int i = StrokePictureCache.strokeCount; i < unselectedStrokes.length; i++) {
        _drawStroke(recordCanvas, unselectedStrokes[i]);
      }
      
      StrokePictureCache.picture?.dispose();
      StrokePictureCache.picture = recorder.endRecording();
      StrokePictureCache.strokeCount = unselectedStrokes.length;
    }

    // 1. Draw the cached unselected strokes
    if (StrokePictureCache.picture != null) {
      canvas.drawPicture(StrokePictureCache.picture!);
    }

    // 2. Draw the selected transforming strokes on top
    final selectedStrokes = strokes.where((s) => selectedIds.contains(s.id)).toList();
    for (final stroke in selectedStrokes) {
      final isTransforming = selectionState.isTransforming;
      if (isTransforming) {
        canvas.save();
        canvas.translate(selectionState.currentTranslation.dx, selectionState.currentTranslation.dy);
        if (selectionState.currentScale != 1.0 && selectionState.selectionBounds != null) {
           final center = selectionState.selectionBounds!.center;
           canvas.translate(center.dx, center.dy);
           canvas.scale(selectionState.currentScale);
           canvas.translate(-center.dx, -center.dy);
        }
      }

      _drawStroke(canvas, stroke);

      if (isTransforming) {
        canvas.restore();
      }
    }
    
    canvas.restore();
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser 
          ? Colors.transparent 
          : Color(stroke.color).withValues(alpha: stroke.opacity)
      ..blendMode = stroke.isEraser ? BlendMode.clear : BlendMode.srcOver
      ..style = PaintingStyle.fill;

    Path? path = _pathCache[stroke];
    if (path == null) {
      final inputPoints = stroke.points
          .map((p) => PointVector(p.x, p.y, p.pressure))
          .toList();

      final outlinePoints = getStroke(
        inputPoints,
        options: StrokeOptions(
          size: stroke.size,
          thinning: 0.7,
          smoothing: 0.5,
          streamline: 0.5,
          simulatePressure: false,
          isComplete: true,
        ),
      );

      if (outlinePoints.isEmpty) return;
      path = _buildPath(outlinePoints);
      _pathCache[stroke] = path;
    }

    canvas.drawPath(path, paint);
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

  @override
  bool shouldRepaint(StrokeHistoryLayer oldDelegate) =>
      strokes != oldDelegate.strokes || selectionState != oldDelegate.selectionState;
}
