import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../../../domain/models/imported_content.dart';

class ImportedContentLayer extends CustomPainter {
  final List<ImportedContent> contents;
  final Map<String, ui.Image> loadedImages;
  final Size canvasSize;

  const ImportedContentLayer({
    required this.contents,
    required this.loadedImages,
    required this.canvasSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (contents.isEmpty) return;

    final sorted = List<ImportedContent>.from(contents)
      ..sort((a, b) => a.zOrder.compareTo(b.zOrder));

    for (final content in sorted) {
      final image = loadedImages[content.id];
      if (image == null) continue;

      final paint = Paint()
        ..color = Color.fromRGBO(255, 255, 255, content.opacity)
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;

      if (content.type == ImportedContentType.pdfBackground) {
        // Draw full-canvas background, scaled to fit
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(0, 0, size.width, size.height),
          paint,
        );
      } else {
        // Draw free image at specified position/size/rotation
        canvas.save();
        canvas.translate(content.x + content.width / 2, content.y + content.height / 2);
        canvas.rotate(content.rotation);
        
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          Rect.fromLTWH(-content.width / 2, -content.height / 2, content.width, content.height),
          paint,
        );
        
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(ImportedContentLayer oldDelegate) {
    return contents != oldDelegate.contents || 
           loadedImages != oldDelegate.loadedImages || 
           canvasSize != oldDelegate.canvasSize;
  }
}
