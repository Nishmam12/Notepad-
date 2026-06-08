import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/models/shape_element.dart';
import '../../../domain/models/shape_type.dart';
import '../../../domain/services/shape_geometry.dart';
import '../../selection_notifier.dart';

class ShapeLayer extends CustomPainter {
  final List<ShapeElement> shapes;
  final SelectionState selectionState;

  const ShapeLayer({
    required this.shapes,
    required this.selectionState,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw in zOrder ascending
    final sorted = [...shapes]..sort((a, b) => a.zOrder.compareTo(b.zOrder));
    for (final shape in sorted) {
      final isSelectedTransforming = selectionState.isTransforming && selectionState.selectedShapeIds.contains(shape.id);
      if (isSelectedTransforming) {
        canvas.save();
        canvas.translate(selectionState.currentTranslation.dx, selectionState.currentTranslation.dy);
        if (selectionState.currentScale != 1.0 && selectionState.selectionBounds != null) {
           final center = selectionState.selectionBounds!.center;
           canvas.translate(center.dx, center.dy);
           canvas.scale(selectionState.currentScale);
           canvas.translate(-center.dx, -center.dy);
        }
      }

      _drawShape(canvas, shape);

      if (isSelectedTransforming) {
        canvas.restore();
      }
    }
  }

  void _drawShape(Canvas canvas, ShapeElement shape) {
    canvas.save();
    // Apply rotation around shape centre
    final centre = _shapeCentre(shape);
    canvas.translate(centre.dx, centre.dy);
    canvas.rotate(shape.rotation);
    canvas.translate(-centre.dx, -centre.dy);

    final strokePaint = Paint()
      ..color = Color(shape.color).withOpacity(shape.opacity)
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = Color(shape.fillColor).withOpacity(shape.hasFill ? shape.opacity : 0)
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
        _drawSvgPlaceholder(canvas, shape, strokePaint);
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
    )..pushStyle(ui.TextStyle(color: Color(shape.color).withOpacity(shape.opacity)))
     ..addText(shape.text);
    
    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: rect.width));
      
    canvas.drawParagraph(paragraph, rect.topLeft);
  }

  Offset _shapeCentre(ShapeElement shape) {
    if (shape.type == ShapeType.circle || shape.type == ShapeType.rectangle || shape.type == ShapeType.textBox || shape.type == ShapeType.svgImage) {
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

  void _drawSvgPlaceholder(Canvas canvas, ShapeElement shape, Paint paint) {
    final rect = ShapeGeometry.rectFromGeometry(shape.geometryData);
    canvas.drawRect(rect, paint..color = paint.color.withOpacity(0.4));
  }

  @override
  bool shouldRepaint(ShapeLayer oldDelegate) => 
      shapes != oldDelegate.shapes || selectionState != oldDelegate.selectionState;
}
