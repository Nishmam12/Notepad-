import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/services/lasso_hit_tester.dart';

class SelectionState {
  final Set<String> selectedStrokeIds;
  final Set<String> selectedShapeIds;
  final Rect? selectionBounds;
  final bool isTransforming;

  const SelectionState({
    this.selectedStrokeIds = const {},
    this.selectedShapeIds = const {},
    this.selectionBounds,
    this.isTransforming = false,
  });

  bool get hasSelection => selectedStrokeIds.isNotEmpty || selectedShapeIds.isNotEmpty;

  SelectionState copyWith({
    Set<String>? selectedStrokeIds,
    Set<String>? selectedShapeIds,
    Rect? selectionBounds,
    bool? isTransforming,
  }) {
    return SelectionState(
      selectedStrokeIds: selectedStrokeIds ?? this.selectedStrokeIds,
      selectedShapeIds: selectedShapeIds ?? this.selectedShapeIds,
      selectionBounds: selectionBounds ?? this.selectionBounds,
      isTransforming: isTransforming ?? this.isTransforming,
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
      );
    }
  }

  void scaleSelection(double scaleFactor) {
    // Only visual update to bounds if needed during transform
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
    state = state.copyWith(isTransforming: false);
  }
}

final selectionProvider = StateNotifierProvider.autoDispose<SelectionNotifier, SelectionState>(
  (ref) => SelectionNotifier(),
);
