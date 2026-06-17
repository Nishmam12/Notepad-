// Canvas widget that assembles all canvas layers in a Stack with RepaintBoundary.

import 'package:flutter/material.dart';

import '../../domain/models/stroke.dart';
import '../../domain/models/stroke_point.dart';
import '../../domain/models/template_type.dart';
import 'layers/background_layer.dart';
import 'layers/active_stroke_layer.dart';
import 'layers/imported_content_layer.dart';
import '../imported_content_notifier.dart';
import '../../domain/models/shape_element.dart';
import '../selection_notifier.dart';
import 'layers/combined_content_layer.dart';
import 'layers/selection_layer.dart';
import 'layers/eraser_trail_layer.dart';

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
  final List<ShapeElement> shapes;
  final ShapeElement? previewShape;
  final SelectionState selectionState;
  final List<Offset>? lassoPreviewPath;
  final int pageIndex;
  final Set<String> pendingEraseStrokeIds;
  final Set<String> pendingEraseShapeIds;
  final bool showEraserTrail;

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
    this.shapes = const [],
    this.previewShape,
    this.selectionState = const SelectionState(),
    this.lassoPreviewPath,
    required this.pageIndex,
    this.pendingEraseStrokeIds = const {},
    this.pendingEraseShapeIds = const {},
    this.showEraserTrail = false,
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

        // Layer 2: Combined content — completed strokes AND vector shapes inside
        // one saveLayer, so the (pixel) eraser clears both. The live pixel-erase
        // stroke is applied here too, which is why there is no separate trail.
        RepaintBoundary(
          child: CustomPaint(
            painter: CombinedContentLayer(
              strokes: completedStrokes,
              shapes: shapes,
              previewShape: previewShape,
              selectionState: selectionState,
              pageIndex: pageIndex,
              activeEraserPoints: isEraser ? currentStrokePoints : const [],
              activeEraserSize: currentStrokeSize,
              isErasing: isEraser,
              pendingEraseStrokeIds: pendingEraseStrokeIds,
              pendingEraseShapeIds: pendingEraseShapeIds,
            ),
            size: Size.infinite,
          ),
        ),

        // Layer 3: Active Stroke — ONLY the live in-progress pen stroke.
        // This is the only layer that repaints during pen input (~every 8ms).
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

        // Layer 4: SelectionLayer
        RepaintBoundary(
          child: CustomPaint(
            painter: SelectionLayer(
              selectionState: selectionState,
              lassoPreviewPath: lassoPreviewPath,
            ),
            size: Size.infinite,
          ),
        ),

        // Layer 5: animated eraser trail (only while the stroke eraser is used).
        if (showEraserTrail)
          const RepaintBoundary(child: EraserTrailLayer()),
      ],
    );
  }
}
