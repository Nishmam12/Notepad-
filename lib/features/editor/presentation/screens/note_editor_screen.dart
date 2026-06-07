// Full-screen editor screen with canvas, toolbar, and stroke persistence.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../canvas_notifier.dart';
import '../canvas/canvas_widget.dart';
import '../canvas/input/raw_pointer_listener.dart';
import '../widgets/tool_bar.dart';
import '../widgets/export_menu.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../../domain/undo_redo/stroke_add_command.dart';
import '../../data/storage/ink_file_storage.dart';

/// Uses ConsumerStatefulWidget only for lifecycle (load/save).
/// All business state remains in Riverpod providers.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final int notebookId;

  const NoteEditorScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  // Using page ID 0 for the first page (multi-page support in Phase 3).
  int get _pageId => 0;

  @override
  void initState() {
    super.initState();
    _loadStrokes();
  }

  Future<void> _loadStrokes() async {
    final strokes = await InkFileStorage.loadStrokes(
      notebookId: widget.notebookId,
      pageId: _pageId,
    );
    if (mounted) {
      ref.read(canvasStateProvider.notifier).loadStrokes(strokes);
    }
  }

  Future<void> _saveStrokes() async {
    final strokes = ref.read(canvasStateProvider).completedStrokes;
    await InkFileStorage.saveStrokes(
      notebookId: widget.notebookId,
      pageId: _pageId,
      strokes: strokes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canvasState = ref.watch(canvasStateProvider);
    final toolState = ref.watch(toolProvider);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _saveStrokes();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              _saveStrokes();
              Navigator.of(context).pop();
            },
          ),
          title: const Text(
            'Editor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            ExportMenu(
              strokes: canvasState.completedStrokes,
              templateType: toolState.template,
              notebookTitle: 'InkFlow Note',
            ),
          ],
        ),
        body: Stack(
          children: [
            RawPointerListener(
              onPointerDown: (point) {
                if (toolState.isEraser) {
                  ref.read(canvasStateProvider.notifier).eraseAtPoint(point, toolState.size * 2);
                } else {
                  ref.read(canvasStateProvider.notifier).addPoint(point);
                }
              },
              onPointerMove: (point) {
                if (toolState.isEraser) {
                  ref.read(canvasStateProvider.notifier).eraseAtPoint(point, toolState.size * 2);
                } else {
                  ref.read(canvasStateProvider.notifier).addPoint(point);
                }
              },
              onPointerUp: () {
                if (!toolState.isEraser) {
                  ref.read(canvasStateProvider.notifier).finishStroke(
                        toolState.color,
                        toolState.size,
                        toolState.opacity,
                      );
                  // Push the command to the undo stack.
                  final strokes = ref.read(canvasStateProvider).completedStrokes;
                  if (strokes.isNotEmpty) {
                    final command = StrokeAddCommand(
                      canvasNotifier: ref.read(canvasStateProvider.notifier),
                      stroke: strokes.last,
                    );
                    ref.read(undoRedoProvider.notifier).push(command);
                  }
                }
              },
              child: CanvasWidget(
                completedStrokes: canvasState.completedStrokes,
                currentStrokePoints: canvasState.currentStrokePoints,
                currentStrokeColor: toolState.color,
                currentStrokeSize: toolState.size,
                currentStrokeOpacity: toolState.opacity,
                templateType: toolState.template,
              ),
            ),
            const ToolBar(),
          ],
        ),
      ),
    );
  }
}
