// StateNotifier managing current stroke points and completed strokes.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/stroke.dart';
import '../domain/models/stroke_point.dart';
import '../domain/models/template_type.dart';

/// Immutable state for the canvas.
class CanvasState {
  final List<Stroke> completedStrokes;
  final List<StrokePoint> currentStrokePoints;

  const CanvasState({
    this.completedStrokes = const [],
    this.currentStrokePoints = const [],
  });

  CanvasState copyWith({
    List<Stroke>? completedStrokes,
    List<StrokePoint>? currentStrokePoints,
  }) {
    return CanvasState(
      completedStrokes: completedStrokes ?? this.completedStrokes,
      currentStrokePoints: currentStrokePoints ?? this.currentStrokePoints,
    );
  }
}

enum EraserType {
  stroke,
  pixel,
}

/// Immutable state for the active drawing tool.
class ToolState {
  final Color color;
  final double size;
  final double opacity;
  final bool isEraser;
  final EraserType eraserType;
  final TemplateType template;

  const ToolState({
    this.color = Colors.black,
    this.size = 4.0,
    this.opacity = 1.0,
    this.isEraser = false,
    this.eraserType = EraserType.stroke,
    this.template = TemplateType.blank,
  });

  factory ToolState.initial() => const ToolState();

  ToolState copyWith({
    Color? color,
    double? size,
    double? opacity,
    bool? isEraser,
    EraserType? eraserType,
    TemplateType? template,
  }) {
    return ToolState(
      color: color ?? this.color,
      size: size ?? this.size,
      opacity: opacity ?? this.opacity,
      isEraser: isEraser ?? this.isEraser,
      eraserType: eraserType ?? this.eraserType,
      template: template ?? this.template,
    );
  }
}

class CanvasStateNotifier extends StateNotifier<CanvasState> {
  CanvasStateNotifier() : super(const CanvasState());

  /// Adds a point to the current in-progress stroke.
  void addPoint(StrokePoint point) {
    state = state.copyWith(
      currentStrokePoints: [...state.currentStrokePoints, point],
    );
  }

  /// Finishes the current stroke and adds it to the completed strokes list.
  void finishStroke(Color color, double size, double opacity, {bool isEraser = false}) {
    if (state.currentStrokePoints.isEmpty) return;

    final stroke = Stroke(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      color: color.toARGB32(),
      size: size,
      opacity: opacity,
      isEraser: isEraser,
      points: List.from(state.currentStrokePoints),
    );

    state = CanvasState(
      completedStrokes: [...state.completedStrokes, stroke],
      currentStrokePoints: const [],
    );
  }

  /// Removes the last stroke (for undo).
  Stroke? removeLastStroke() {
    if (state.completedStrokes.isEmpty) return null;

    final removed = state.completedStrokes.last;
    state = state.copyWith(
      completedStrokes: state.completedStrokes.sublist(
        0,
        state.completedStrokes.length - 1,
      ),
    );
    return removed;
  }

  /// Adds a stroke back (for redo).
  void addStroke(Stroke stroke) {
    state = state.copyWith(
      completedStrokes: [...state.completedStrokes, stroke],
    );
  }

  /// Erases any stroke that contains a point or line segment near the given position.
  void eraseAtPoint(StrokePoint point, double eraserRadius) {
    final eraserSq = eraserRadius * eraserRadius;
    final remaining = state.completedStrokes.where((stroke) {
      if (stroke.points.isEmpty) return true;
      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        final dx = p.x - point.x;
        final dy = p.y - point.y;
        return (dx * dx + dy * dy) > eraserSq;
      }

      for (int i = 0; i < stroke.points.length - 1; i++) {
        final p1 = stroke.points[i];
        final p2 = stroke.points[i + 1];

        final l2 = (p2.x - p1.x) * (p2.x - p1.x) + (p2.y - p1.y) * (p2.y - p1.y);
        if (l2 == 0) {
          final dx = p1.x - point.x;
          final dy = p1.y - point.y;
          if ((dx * dx + dy * dy) <= eraserSq) return false;
          continue;
        }

        double t = ((point.x - p1.x) * (p2.x - p1.x) + (point.y - p1.y) * (p2.y - p1.y)) / l2;
        t = t.clamp(0.0, 1.0);

        final projX = p1.x + t * (p2.x - p1.x);
        final projY = p1.y + t * (p2.y - p1.y);

        final dx = point.x - projX;
        final dy = point.y - projY;

        if ((dx * dx + dy * dy) <= eraserSq) {
          return false;
        }
      }
      return true;
    }).toList();

    if (remaining.length != state.completedStrokes.length) {
      state = state.copyWith(completedStrokes: remaining);
    }
  }

  /// Replaces all strokes (used when loading from storage).
  void loadStrokes(List<Stroke> strokes) {
    state = CanvasState(
      completedStrokes: strokes,
      currentStrokePoints: const [],
    );
  }

  /// Clears all strokes.
  void clearAll() {
    state = const CanvasState();
  }
}

class ToolNotifier extends StateNotifier<ToolState> {
  ToolNotifier() : super(ToolState.initial());

  void setColor(Color color) => state = state.copyWith(color: color);
  void setSize(double size) => state = state.copyWith(size: size);
  void setOpacity(double opacity) => state = state.copyWith(opacity: opacity);
  void toggleEraser() => state = state.copyWith(isEraser: !state.isEraser);
  void toggleEraserType() {
    state = state.copyWith(
      eraserType: state.eraserType == EraserType.stroke
          ? EraserType.pixel
          : EraserType.stroke,
    );
  }
  void setPen() => state = state.copyWith(isEraser: false);
  void setEraser() => state = state.copyWith(isEraser: true);
  void setTemplate(TemplateType template) =>
      state = state.copyWith(template: template);
}

/// Canvas state provider — auto-disposes when leaving the editor screen.
final canvasStateProvider =
    StateNotifierProvider.autoDispose<CanvasStateNotifier, CanvasState>(
  (ref) => CanvasStateNotifier(),
);

/// Tool state provider — persists across editor sessions.
final toolProvider = StateNotifierProvider<ToolNotifier, ToolState>(
  (ref) => ToolNotifier(),
);
