import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:perfect_freehand/perfect_freehand.dart';

import '../../domain/models/stroke.dart';
import '../../domain/models/imported_content.dart';

class PageThumbnailService {
  static Future<String> _thumbnailPath(int notebookId, int pageIndex) async {
    final appDir = await getApplicationDocumentsDirectory();
    final dir = '${appDir.path}/notes/$notebookId/thumbnails';
    await Directory(dir).create(recursive: true);
    return '$dir/page_$pageIndex.png';
  }

  /// Called during autosave to render the current page in the background.
  static Future<void> generateAndSave(
    int notebookId,
    int pageIndex,
    List<Stroke> strokes,
    List<ImportedContent> contents,
    Map<String, ui.Image> loadedImages,
    ui.Size size,
  ) async {
    // 1. Render to image on main thread (very fast, GPU backed)
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Offset.zero & size,
      ui.Paint()..color = const ui.Color(0xFF0D1117), // AppColors.background
    );

    // Draw imported contents first (Layer 1)
    for (final content in contents) {
      final img = loadedImages[content.id];
      if (img != null) {
        canvas.save();
        canvas.translate(content.x + content.width / 2, content.y + content.height / 2);
        canvas.rotate(content.rotation);
        final destRect = ui.Rect.fromLTWH(-content.width / 2, -content.height / 2, content.width, content.height);
        
        // Manual drawImageRect to replicate paintImage without importing flutter/widgets.dart
        canvas.drawImageRect(
          img,
          ui.Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
          destRect,
          ui.Paint(),
        );
        canvas.restore();
      }
    }

    // Draw strokes (Layer 2 & 3)
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final path = ui.Path();
      final points = stroke.points;
      
      if (points.length == 1) {
        path.addOval(ui.Rect.fromCircle(
          center: ui.Offset(points.first.x, points.first.y),
          radius: stroke.size / 2,
        ));
      } else {
        final pointVectors = points.map((p) => PointVector(p.x, p.y, p.pressure)).toList();
        final outline = getStroke(
          pointVectors,
          options: StrokeOptions(
            size: stroke.size,
            thinning: 0.5,
            smoothing: 0.5,
            streamline: 0.5,
          ),
        );
        if (outline.isEmpty) continue;
        path.moveTo(outline.first.dx, outline.first.dy);
        for (int i = 1; i < outline.length - 1; i++) {
          final p0 = outline[i];
          final p1 = outline[i + 1];
          path.quadraticBezierTo(p0.dx, p0.dy, (p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
        }
      }

      final paint = ui.Paint()
        ..color = ui.Color(stroke.color).withValues(alpha: stroke.opacity)
        ..style = ui.PaintingStyle.fill;
        
      if (stroke.isEraser) {
        paint.blendMode = ui.BlendMode.clear;
      }

      canvas.drawPath(path, paint);
    }

    final picture = recorder.endRecording();
    // Use a smaller scale for the thumbnail (e.g., 1/4 size) to save memory
    final img = await picture.toImage(
      (size.width * 0.25).toInt(),
      (size.height * 0.25).toInt(),
    );

    // 2. Encode to PNG asynchronously (this is the heavy part)
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;

    final bytes = byteData.buffer.asUint8List();
    
    final path = await _thumbnailPath(notebookId, pageIndex);

    // 3. Write to disk using compute to prevent IO jank
    await compute(_writeBytesToDisk, _WriteTask(path, bytes));
  }

  /// Returns raw image data lazily, fetching from disk if exists
  static Future<ui.Image?> getThumbnailLazy(int notebookId, int pageIndex) async {
    final path = await _thumbnailPath(notebookId, pageIndex);
    final file = File(path);
    if (!await file.exists()) return null;

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (e) {
      // If the image is corrupted or incomplete, return null instead of crashing
      return null;
    }
  }
}

class _WriteTask {
  final String path;
  final Uint8List bytes;
  _WriteTask(this.path, this.bytes);
}

Future<void> _writeBytesToDisk(_WriteTask task) async {
  final file = File(task.path);
  await file.writeAsBytes(task.bytes);
}
