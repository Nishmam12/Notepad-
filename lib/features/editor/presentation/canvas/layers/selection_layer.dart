import 'package:flutter/material.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../selection_notifier.dart';

class SelectionLayer extends CustomPainter {
  final SelectionState selectionState;
  final List<Offset>? lassoPreviewPath;

  const SelectionLayer({required this.selectionState, this.lassoPreviewPath});

  @override
  void paint(Canvas canvas, Size size) {
    if (lassoPreviewPath != null && lassoPreviewPath!.length > 1) {
      final lassoPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.6)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;
      final path = Path()..addPolygon(lassoPreviewPath!, false);
      canvas.drawPath(path, lassoPaint);
      
      final fillPaint = Paint()
        ..color = AppColors.accent.withValues(alpha: 0.08)
        ..style = PaintingStyle.fill;
      canvas.drawPath(Path()..addPolygon(lassoPreviewPath!, true), fillPaint);
    }

    if (selectionState.hasSelection && selectionState.selectionBounds != null) {
      final bounds = selectionState.selectionBounds!.inflate(4.0);
      final selectionPaint = Paint()
        ..color = AppColors.accent
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke;
      
      // Draw dashed rectangle manually
      final path = Path()..addRect(bounds);
      canvas.drawPath(path, selectionPaint); 
      // Ideally dashed, but sticking to simple rect if complex dash isn't strictly required or can be done with Path.
    }
  }

  @override
  bool shouldRepaint(SelectionLayer oldDelegate) =>
      selectionState != oldDelegate.selectionState ||
      lassoPreviewPath != oldDelegate.lassoPreviewPath;
}
