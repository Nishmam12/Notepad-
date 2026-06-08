import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/services/lasso_hit_tester.dart';

class SelectionState {
  final Set<String> selectedStrokeIds;
  final Set<String> selectedShapeIds;
  final Rect? selectionBounds;
  final bool isTransforming;
  final Offset currentTranslation;
  final double currentScale;

  const SelectionState({
    this.selectedStrokeIds = const {},
    this.selectedShapeIds = const {},
    this.selectionBounds,
    this.isTransforming = false,
    this.currentTranslation = Offset.zero,
    this.currentScale = 1.0,
  });

  bool get hasSelection => selectedStrokeIds.isNotEmpty || selectedShapeIds.isNotEmpty;

  SelectionState copyWith({
    Set<String>? selectedStrokeIds,
    Set<String>? selectedShapeIds,
    Rect? selectionBounds,
    bool? isTransforming,
    Offset? currentTranslation,
    double? currentScale,
  }) {
    return SelectionState(
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      selectedShapeIds: selectedShapeIds ?? this.selectedShapeIds,
      selectionBounds: selectionBounds ?? this.selectionBounds,
      isTransforming: isTransforming ?? this.isTransforming,
      currentTranslation: currentTranslation ?? this.currentTranslation,
      currentScale: currentScale ?? this.currentScale,
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

  void moveSelection(Offset delta) {
    if (state.selectionBounds != null) {
      state = state.copyWith(
        selectionBounds: state.selectionBounds!.shift(delta),
        currentTranslation: state.currentTranslation + delta,
      );
    }
  }

  void scaleSelection(double scaleFactor) {
    if (state.selectionBounds != null) {
      // In a real robust implementation, we would scale the bounds relative to its center or the opposite corner.
      // For now, we'll just track the scale factor for the canvas transform and approximate the bounds.
      final center = state.selectionBounds!.center;
      final newWidth = state.selectionBounds!.width * scaleFactor;
      final newHeight = state.selectionBounds!.height * scaleFactor;
      state = state.copyWith(
        currentScale: state.currentScale * scaleFactor,
        selectionBounds: Rect.fromCenter(center: center, width: newWidth, height: newHeight),
      );
    }
  }

  void rotateSelection(double deltaRadians) {
    // Only visual update to bounds if needed during transform
  }

  void deleteSelection() {
    clearSelection();
  }

  void beginTransform() {
    state = state.copyWith(isTransforming: true);
  }

  void endTransform() {
    state = state.copyWith(
      isTransforming: false,
      currentTranslation: Offset.zero,
      currentScale: 1.0,
    );
  }
}

final selectionProvider = StateNotifierProvider.autoDispose<SelectionNotifier, SelectionState>(
  (ref) => SelectionNotifier(),
);
