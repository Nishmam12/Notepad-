// Canvas widget that assembles all canvas layers in a Stack with RepaintBoundary.

import 'package:flutter/material.dart';

import '../../domain/models/stroke.dart';
import '../../domain/models/stroke_point.dart';
import '../../domain/models/template_type.dart';
import 'layers/background_layer.dart';
import 'layers/stroke_history_layer.dart';
import 'layers/active_stroke_layer.dart';
import 'layers/imported_content_layer.dart';
import '../imported_content_notifier.dart';

class CanvasWidget extends StatelessWidget {
  final List<Stroke> completedStrokes;
  final List<StrokePoint> currentStrokePoints;
  final Color currentStrokeColor;
  final double currentStrokeSize;
  final double currentStrokeOpacity;
  final ImportedContentState importedContentState;
  final Color backgroundColor;
  final bool isEraser;
  final TemplateType templateType;

  const CanvasWidget({
    super.key,
    required this.completedStrokes,
    required this.currentStrokePoints,
    required this.currentStrokeColor,
    required this.currentStrokeSize,
    required this.importedContentState,
    this.currentStrokeOpacity = 1.0,
    this.isEraser = false,
    this.backgroundColor = Colors.white,
    this.templateType = TemplateType.blank,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Layer 0: Background — never repaints during drawing.
        RepaintBoundary(
          child: CustomPaint(
            painter: BackgroundLayer(
              backgroundColor: backgroundColor,
              templateType: templateType,
            ),
            size: Size.infinite,
          ),
        ),

        // Layer 1: ImportedContentLayer — PDF pages and images.
        RepaintBoundary(
          child: CustomPaint(
            painter: ImportedContentLayer(
              contents: importedContentState.contents,
              loadedImages: importedContentState.loadedImages,
              canvasSize: MediaQuery.of(context).size,
            ),
            size: Size.infinite,
          ),
        ),

        // Layer 2: Stroke History — completed strokes, cached as GPU texture.
        RepaintBoundary(
          child: CustomPaint(
            painter: StrokeHistoryLayer(strokes: completedStrokes),
            size: Size.infinite,
          ),
        ),

        // Layer 3: Active Stroke — ONLY the live in-progress stroke.
        // This is the only layer that repaints during input (~every 8ms).
        RepaintBoundary(
          child: CustomPaint(
            painter: ActiveStrokeLayer(
              currentStrokePoints: currentStrokePoints,
              strokeColor: currentStrokeColor,
              strokeSize: currentStrokeSize,
              strokeOpacity: currentStrokeOpacity,
              isEraser: isEraser,
            ),
            size: Size.infinite,
          ),
        ),

        // Layer 4: ShapeLayer — placeholder for Phase 5.
        // Will hold vector shapes and text boxes.

        // Layer 5: SelectionLayer — placeholder for Phase 5.
        // Will hold selection handles and UI overlay.
      ],
    );
  }
}
