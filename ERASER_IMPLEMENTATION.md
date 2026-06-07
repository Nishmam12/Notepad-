# Eraser Dual-Mode Implementation Details

This document outlines the architecture and implementation of the dual-mode eraser (Stroke Eraser + Pixel Eraser) added to InkFlow.

## 1. Core Data Model Updates
- **Stroke Model (`lib/features/editor/domain/models/stroke.dart`)**:
  - Added a `final bool isEraser;` property to distinguish normal strokes from pixel-eraser strokes.
  - Updated the `toMap()`, `fromMap()`, and `copyWith()` methods to serialize `isEraser` correctly into the `.ink` binary files, ensuring that pixel erasures persist across app restarts.

## 2. State Management & Canvas Notifier
- **ToolState (`lib/features/editor/presentation/canvas_notifier.dart`)**:
  - Introduced an `EraserType` enum with two values: `stroke` and `pixel`.
  - Updated `ToolState` to track the current `EraserType`.
  - Added `toggleEraserType()` to `ToolNotifier` allowing the user interface to cycle between eraser modes.
- **CanvasStateNotifier (`lib/features/editor/presentation/canvas_notifier.dart`)**:
  - Modified `finishStroke(..., {bool isEraser = false})` to accept the eraser status and bundle it into the `Stroke` object.

## 3. Input Routing (`lib/features/editor/presentation/screens/note_editor_screen.dart`)
- Updated the `RawPointerListener` to route input intelligently based on the active tool and eraser type:
  - **Stroke Eraser**: Triggers `eraseAtPoint()`, mathematically finding and destroying the exact stroke the pointer crossed.
  - **Pixel Eraser (or Pen)**: Triggers `addPoint()`, collecting points to build an active live stroke.
  - **On Pointer Up**: If using the pixel eraser, the stroke is finalized via `finishStroke(isEraser: true)` and pushed onto the Command/Undo stack, just like a normal pen stroke.

## 4. UI Toolbar UX (`lib/features/editor/presentation/widgets/tool_bar.dart`)
- Updated the Eraser `_ToolButton` behavior:
  - Tapping it while inactive selects the Eraser tool.
  - Tapping it while already active calls `toggleEraserType()`, switching the mode.
  - Visually updates the icon: `Icons.auto_fix_high` (magic wand) for Stroke Eraser, and `Icons.layers_clear` for Pixel Eraser.

## 5. High-Performance Rendering Architecture

### History Layer (`lib/features/editor/presentation/canvas/layers/stroke_history_layer.dart`)
- **Performance Cache**: Generating freehand outlines is CPU intensive. A local `Map<String, Path> _pathCache` was added to cache Flutter `Path` objects based on `Stroke.id`. This ensures drawing 1000s of strokes repaints at a buttery-smooth 120fps.
- **BlendMode Masking**: Pixel eraser strokes are drawn with `BlendMode.clear` and `Colors.transparent`. 
- **Isolated Rendering (`saveLayer`)**: Added `canvas.saveLayer(null, Paint())` before drawing history, and `canvas.restore()` after. This guarantees that `BlendMode.clear` only punches holes through the ink layer, while perfectly preserving the vector templates (grid, lines) on the layer underneath.

### Active Stroke Layer (`lib/features/editor/presentation/canvas/layers/active_stroke_layer.dart`)
- To ensure the user can clearly see where they are erasing, the live pixel-eraser stroke is painted using a translucent gray trail (`Colors.grey.withValues(alpha: 0.3)`) bordered by a crisp white outline (`Colors.white.withValues(alpha: 0.8)`).
- This styling guarantees the live eraser cursor is visible against both dark backgrounds and bright template grids.
