import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/models/shape_element.dart';
import '../domain/services/shape_hit_tester.dart';
import '../data/repositories/shape_repository.dart';

class ShapeState {
  final List<ShapeElement> shapes;
  final bool isLoading;
  final String? errorMessage;

  const ShapeState({
    this.shapes = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  ShapeState copyWith({
    List<ShapeElement>? shapes,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ShapeState(
      shapes: shapes ?? this.shapes,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ShapeNotifier extends StateNotifier<ShapeState> {
  final int pageIndex;
  final ShapeRepository _repository;

  ShapeNotifier(this.pageIndex, this._repository) : super(const ShapeState());

  /// Current shapes (read-only access for commands/services).
  List<ShapeElement> get currentShapes => state.shapes;

  Future<void> loadForPage(int notebookId) async {
    state = state.copyWith(isLoading: true);
    try {
      final shapes = await _repository.getShapesForPage(notebookId, pageIndex);
      if (!mounted) return;
      state = state.copyWith(shapes: shapes, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, errorMessage: e.toString());
    }
  }

  Future<void> addShape(ShapeElement shape) async {
    // Optimistic UI update
    state = state.copyWith(shapes: [...state.shapes, shape]);
    // Note: To truly persist we'd need notebookId here, or we wait for forceSave.
    // In InkFlow, strokes are force-saved on page change or export.
    // If we need to write immediately, we'd need notebookId injected or passed.
    // Wait, the prompt says `void addShape(ShapeElement shape) async { ... if (!mounted) return; ... }`
    // Actually, shapes are embedded in NotePage, they will be saved synchronously if we have notebookId.
    // Given we don't have notebookId in `addShape`, we might just maintain memory state and rely on forceSave, OR 
    // we can pass notebookId to addShape. The prompt didn't add notebookId to addShape parameters.
    // Let's just update memory state. Wait, the prompt says "Undo after placing shape -> shape removed from canvas and Isar".
    // This implies we don't save to Isar on every stroke, but maybe we do for shapes?
    // Let's leave Isar persisting to force-save (I-5: `await _forceSaveShapes(oldPageIndex, oldShapes);`).
    // So addShape just updates memory.
  }

  void removeShape(String id) {
    if (!mounted) return;
    state = state.copyWith(
      shapes: state.shapes.where((s) => s.id != id).toList(),
    );
  }

  void updateShape(ShapeElement updated) {
    if (!mounted) return;
    final index = state.shapes.indexWhere((s) => s.id == updated.id);
    if (index != -1) {
      final newList = List<ShapeElement>.from(state.shapes);
      newList[index] = updated;
      state = state.copyWith(shapes: newList);
    }
  }

  /// Removes any shapes within [radius] of [point] (used by the stroke eraser).
  /// Returns the removed shapes so callers can record them for undo.
  List<ShapeElement> eraseAtPoint(Offset point, double radius) {
    if (!mounted) return const [];
    final removed = <ShapeElement>[];
    final remaining = <ShapeElement>[];
    for (final shape in state.shapes) {
      if (ShapeHitTester.isHit(shape, point, radius)) {
        removed.add(shape);
      } else {
        remaining.add(shape);
      }
    }
    if (removed.isNotEmpty) {
      state = state.copyWith(shapes: remaining);
    }
    return removed;
  }

  void clearShapes() {
    if (!mounted) return;
    state = state.copyWith(shapes: []);
  }
}

final shapeProvider = StateNotifierProvider.autoDispose.family<ShapeNotifier, ShapeState, int>(
  (ref, pageIndex) => ShapeNotifier(pageIndex, ShapeRepository()),
);
