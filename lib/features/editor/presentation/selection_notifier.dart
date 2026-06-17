import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/services/lasso_hit_tester.dart';

/// Live state for a lasso selection and its in-progress transform.
///
/// A transform gesture is one of three mutually-exclusive kinds — move, resize
/// (uniform scale anchored at the opposite corner) or rotate (around the bounds
/// centre). Each is captured here as a delta off [baseBounds] (the bounds at
/// [SelectionNotifier.beginTransform]); the canvas preview and the committed
/// [LassoTransformCommand] both read these and apply the same affine map.
class SelectionState {
  final Set<String> selectedStrokeIds;
  final Set<String> selectedShapeIds;
  final Rect? selectionBounds;
  final bool isTransforming;

  /// Scene-space translation accumulated during a move gesture.
  final Offset currentTranslation;

  /// Uniform scale factor accumulated during a resize gesture.
  final double currentScale;

  /// Fixed point a resize scales about (the corner opposite the dragged one).
  /// Defaults to the bounds centre when no resize is active.
  final Offset? scaleAnchor;

  /// Rotation (radians, clockwise) accumulated during a rotate gesture.
  final double currentRotation;

  /// Bounds captured at [SelectionNotifier.beginTransform]; the live transform
  /// is expressed relative to this so it is exact regardless of frame cadence.
  final Rect? baseBounds;

  const SelectionState({
    this.selectedStrokeIds = const {},
    this.selectedShapeIds = const {},
    this.selectionBounds,
    this.isTransforming = false,
    this.currentTranslation = Offset.zero,
    this.currentScale = 1.0,
    this.scaleAnchor,
    this.currentRotation = 0.0,
    this.baseBounds,
  });

  bool get hasSelection =>
      selectedStrokeIds.isNotEmpty || selectedShapeIds.isNotEmpty;

  /// Centre the rotate gesture pivots around (the base bounds centre).
  Offset? get rotationCenter => baseBounds?.center ?? selectionBounds?.center;

  SelectionState copyWith({
    Set<String>? selectedStrokeIds,
    Set<String>? selectedShapeIds,
    Rect? selectionBounds,
    bool? isTransforming,
    Offset? currentTranslation,
    double? currentScale,
    Offset? scaleAnchor,
    double? currentRotation,
    Rect? baseBounds,
  }) {
    return SelectionState(
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      selectedShapeIds: selectedShapeIds ?? this.selectedShapeIds,
      selectionBounds: selectionBounds ?? this.selectionBounds,
      isTransforming: isTransforming ?? this.isTransforming,
      currentTranslation: currentTranslation ?? this.currentTranslation,
      currentScale: currentScale ?? this.currentScale,
      scaleAnchor: scaleAnchor ?? this.scaleAnchor,
      currentRotation: currentRotation ?? this.currentRotation,
      baseBounds: baseBounds ?? this.baseBounds,
    );
  }
}

class SelectionNotifier extends StateNotifier<SelectionState> {
  SelectionNotifier() : super(const SelectionState());

  void setSelection(LassoHitResult result, Rect bounds) {
    state = state.copyWith(
      selectedStrokeIds: result.selectedStrokeIds,
      selectedShapeIds: result.selectedShapeIds,
      selectionBounds: bounds,
    );
  }

  void clearSelection() {
    state = const SelectionState();
  }

  /// Snapshots the current bounds and resets all live transform deltas.
  void beginTransform() {
    state = state.copyWith(
      isTransforming: true,
      baseBounds: state.selectionBounds,
      currentTranslation: Offset.zero,
      currentScale: 1.0,
      scaleAnchor: state.selectionBounds?.center,
      currentRotation: 0.0,
    );
  }

  /// Move: absolute scene-space translation off [SelectionState.baseBounds].
  void setMove(Offset sceneTranslation) {
    final base = state.baseBounds;
    if (base == null) return;
    state = state.copyWith(
      currentTranslation: sceneTranslation,
      selectionBounds: base.shift(sceneTranslation),
    );
  }

  /// Resize: uniform [scale] about the fixed [anchor] (opposite corner).
  void setResize(Offset anchor, double scale) {
    final base = state.baseBounds;
    if (base == null) return;
    Offset map(Offset p) => anchor + (p - anchor) * scale;
    state = state.copyWith(
      scaleAnchor: anchor,
      currentScale: scale,
      selectionBounds: Rect.fromPoints(map(base.topLeft), map(base.bottomRight)),
    );
  }

  /// Rotate: absolute angle (radians) about the base bounds centre. The
  /// axis-aligned bounds rectangle is kept at its base so handles stay put.
  void setRotation(double radians) {
    if (state.baseBounds == null) return;
    state = state.copyWith(currentRotation: radians);
  }

  void endTransform() {
    state = state.copyWith(
      isTransforming: false,
      currentTranslation: Offset.zero,
      currentScale: 1.0,
      currentRotation: 0.0,
    );
  }

  void deleteSelection() {
    clearSelection();
  }
}

final selectionProvider =
    StateNotifierProvider.autoDispose<SelectionNotifier, SelectionState>(
  (ref) => SelectionNotifier(),
);
