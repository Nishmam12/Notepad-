// Undo/redo stack managing command history using the Command pattern.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'command.dart';

/// Immutable state for the undo/redo stack.
class UndoRedoState {
  final List<Command> undoStack;
  final List<Command> redoStack;

  const UndoRedoState({
    this.undoStack = const [],
    this.redoStack = const [],
  });

  bool get canUndo => undoStack.isNotEmpty;
  bool get canRedo => redoStack.isNotEmpty;

  UndoRedoState copyWith({
    List<Command>? undoStack,
    List<Command>? redoStack,
  }) {
    return UndoRedoState(
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}

class UndoRedoNotifier extends StateNotifier<UndoRedoState> {
  UndoRedoNotifier() : super(const UndoRedoState());

  /// Pushes a command onto the undo stack and clears the redo stack.
  void push(Command command) {
    state = UndoRedoState(
      undoStack: [...state.undoStack, command],
      redoStack: const [],
    );
  }

  /// Undoes the last command.
  void undo() {
    if (!state.canUndo) return;

    final command = state.undoStack.last;
    command.undo();

    state = UndoRedoState(
      undoStack: state.undoStack.sublist(0, state.undoStack.length - 1),
      redoStack: [...state.redoStack, command],
    );
  }

  /// Redoes the last undone command.
  void redo() {
    if (!state.canRedo) return;

    final command = state.redoStack.last;
    command.execute();

    state = UndoRedoState(
      undoStack: [...state.undoStack, command],
      redoStack: state.redoStack.sublist(0, state.redoStack.length - 1),
    );
  }

  /// Clears both stacks.
  void clear() {
    state = const UndoRedoState();
  }
}

/// Undo/redo provider — auto-disposes when leaving the editor screen.
final undoRedoProvider =
    StateNotifierProvider.autoDispose<UndoRedoNotifier, UndoRedoState>(
  (ref) => UndoRedoNotifier(),
);
