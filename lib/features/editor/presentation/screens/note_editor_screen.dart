// Full-screen editor screen with canvas, toolbar, page navigation, and stroke persistence.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../canvas_notifier.dart';
import '../../domain/models/stroke.dart';
import '../page_notifier.dart';
import '../canvas/canvas_widget.dart';
import '../canvas/input/raw_pointer_listener.dart';
import '../widgets/tool_bar.dart';
import '../widgets/export_menu.dart';
import '../widgets/page_navigator_widget.dart';
import '../widgets/free_image_overlay.dart';
import '../imported_content_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../../domain/undo_redo/stroke_add_command.dart';
import '../../data/storage/ink_file_storage.dart';
import '../../data/storage/page_cache_manager.dart';
import '../../data/storage/page_thumbnail_service.dart';
import '../../domain/models/shape_type.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/services/shape_geometry.dart';
import '../shape_notifier.dart';
import '../selection_notifier.dart';
import '../../domain/undo_redo/shape_add_command.dart';
import '../canvas/input/shape_input_handler.dart';
import '../canvas/input/lasso_input_handler.dart';
import '../widgets/shape_toolbar.dart';
import '../widgets/selection_overlay.dart' as app_sel;
import '../widgets/text_box_overlay.dart';

final lassoPreviewProvider = StateProvider.autoDispose<List<Offset>>((ref) => []);
final activeTextBoxProvider = StateProvider.autoDispose<ShapeElement?>((ref) => null);
final textBoxRectProvider = StateProvider.autoDispose<Rect?>((ref) => null);

class NoteEditorScreen extends ConsumerStatefulWidget {
  final int notebookId;

  const NoteEditorScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> with WidgetsBindingObserver {
  final PageCacheManager _cacheManager = PageCacheManager();
  Timer? _autosaveTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize the page provider to ensure pages are loaded
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pageProvider(widget.notebookId).notifier).initialize().then((_) {
        // For the very first load, old and new are both 0.
        // We can just pass empty list for oldStrokes since there's nothing to save yet.
        _performPageSwitchLoad(0, 0, [], []);
        ref.read(importedContentProvider(0).notifier).loadForPage(widget.notebookId);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveTimer?.cancel();
    _forceSave();
    _cacheManager.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _forceSave();
    }
  }

  void _triggerAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(const Duration(seconds: 2), () {
      _forceSave();
    });
  }

  Future<void> _forceSave({int? pageIndexOverride, List<Stroke>? strokesOverride, List<ShapeElement>? shapesOverride}) async {
    if (_isSaving) return;
    _isSaving = true;

    final pageState = ref.read(pageProvider(widget.notebookId));
    final currentIndex = pageIndexOverride ?? pageState.currentPageIndex;
    final strokes = strokesOverride ?? ref.read(canvasStateProvider(currentIndex)).completedStrokes;
    final shapes = shapesOverride ?? ref.read(shapeProvider(currentIndex)).shapes;
    
    if (pageState.pages.isNotEmpty) {
      final size = MediaQuery.of(context).size;
      final importedState = ref.read(importedContentProvider(currentIndex));
      
      await InkFileStorage.saveStrokes(
        notebookId: widget.notebookId,
        pageId: currentIndex,
        strokes: strokes,
      );
      
      await ShapeRepository().saveShapesForPage(widget.notebookId, currentIndex, shapes);
      
      // Update the thumbnail for the navigator in the background
      PageThumbnailService.generateAndSave(
        widget.notebookId, 
        currentIndex, 
        strokes, 
        importedState.contents,
        importedState.loadedImages,
        shapes,
        size,
      );
      
      // Update modified time in Isar
      ref.read(pageRepositoryProvider).updateModifiedAt(widget.notebookId, currentIndex);
    }
    
    _isSaving = false;
  }

  /// Implements the strict 7-step sequence for switching pages
  Future<void> _performPageSwitchLoad(int oldPageIndex, int newPageIndex, List<Stroke> oldStrokes, List<ShapeElement> oldShapes) async {
    // 1. Autosave current
    await _forceSave(pageIndexOverride: oldPageIndex, strokesOverride: oldStrokes, shapesOverride: oldShapes);
    
    // 2. Clear canvas to prevent ghosting
    ref.read(canvasStateProvider(newPageIndex).notifier).loadStrokes([]);
    ref.read(shapeProvider(newPageIndex).notifier).clearShapes();
    
    // 3. Load target page from cache/disk
    final pageData = await _cacheManager.getPage(widget.notebookId, newPageIndex);
    
    // 4. Restore strokes
    if (mounted) {
      ref.read(canvasStateProvider(newPageIndex).notifier).loadStrokes(pageData.strokes);
      ref.read(importedContentProvider(newPageIndex).notifier).loadForPage(widget.notebookId);
      ref.read(shapeProvider(newPageIndex).notifier).loadForPage(widget.notebookId);
    }
    
    // 5. Preload adjacent pages
    _cacheManager.preloadAdjacent(widget.notebookId, newPageIndex);
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(pageProvider(widget.notebookId));
    final currentIndex = pageState.currentPageIndex;
    final canvasState = ref.watch(canvasStateProvider(currentIndex));
    final importedState = ref.watch(importedContentProvider(currentIndex));
    final toolState = ref.watch(toolProvider);
    final shapeState = ref.watch(shapeProvider(currentIndex));
    final selectionState = ref.watch(selectionProvider);
    final lassoPreviewPath = ref.watch(lassoPreviewProvider);
    final activeTextBox = ref.watch(activeTextBoxProvider);
    final textBoxRect = ref.watch(textBoxRectProvider);

    final shapeInputHandler = ShapeInputHandler(
      onShapeRecognised: (ShapeElement shape) {
        if (shape.type == ShapeType.textBox) {
          ref.read(textBoxRectProvider.notifier).state = ShapeGeometry.rectFromGeometry(shape.geometryData);
        } else {
          ref.read(shapeProvider(currentIndex).notifier).addShape(shape);
          final command = ShapeAddCommand(
            shapeNotifier: ref.read(shapeProvider(currentIndex).notifier),
            shape: shape,
          );
          ref.read(undoRedoProvider(currentIndex).notifier).push(command);
        }
        _triggerAutosave();
      },
      onShapeFallback: (List<StrokePoint> points) {
        final stroke = Stroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          color: toolState.color.toARGB32(),
          size: toolState.size,
          opacity: toolState.opacity,
          isEraser: false,
          points: points,
        );
        ref.read(canvasStateProvider(currentIndex).notifier).addStroke(stroke);
        final command = StrokeAddCommand(
          canvasNotifier: ref.read(canvasStateProvider(currentIndex).notifier),
          stroke: stroke,
        );
        ref.read(undoRedoProvider(currentIndex).notifier).push(command);
        _triggerAutosave();
      },
      toolState: toolState,
    );

    final lassoInputHandler = LassoInputHandler(
      onLassoComplete: (LassoHitResult result, Rect bounds) {
        ref.read(selectionProvider.notifier).setSelection(
          result,
          bounds,
        );
      },
      onLassoUpdate: (List<Offset> path) {
        ref.read(lassoPreviewProvider.notifier).state = path;
      },
      currentStrokes: canvasState.completedStrokes,
      currentShapes: shapeState.shapes,
    );
    
    // Listen for page index changes to trigger the switch sequence
    ref.listen<PageState>(pageProvider(widget.notebookId), (previous, next) {
      if (previous != null && previous.currentPageIndex != next.currentPageIndex) {
        // Read old strokes synchronously before the autoDispose provider is destroyed
        final oldStrokes = ref.read(canvasStateProvider(previous.currentPageIndex)).completedStrokes;
        final oldShapes = ref.read(shapeProvider(previous.currentPageIndex)).shapes;
        _performPageSwitchLoad(previous.currentPageIndex, next.currentPageIndex, oldStrokes, oldShapes);
      }
    });

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          _forceSave();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final nav = Navigator.of(context);
              _forceSave().then((_) {
                if (mounted) nav.pop();
              });
            },
          ),
          title: const Text(
            'Editor',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'Book View',
              onPressed: () {
                _forceSave().then((_) {
                  if (mounted) context.push('/note/${widget.notebookId}/book');
                });
              },
            ),
            ExportMenu(
              strokes: canvasState.completedStrokes,
              templateType: toolState.template,
              notebookTitle: 'InkFlow Note',
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  RawPointerListener(
                    onPointerDown: (event, point) {
                      if (toolState.activeTool == ToolType.shape) {
                        shapeInputHandler.onPointerDown(event as PointerDownEvent);
                      } else if (toolState.activeTool == ToolType.lasso) {
                        lassoInputHandler.onPointerDown(event as PointerDownEvent);
                      } else if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
                        ref.read(canvasStateProvider(currentIndex).notifier).eraseAtPoint(point, toolState.size * 2);
                        _triggerAutosave();
                      } else {
                        ref.read(canvasStateProvider(currentIndex).notifier).addPoint(point);
                      }
                    },
                    onPointerMove: (event, point) {
                      if (toolState.activeTool == ToolType.shape) {
                        shapeInputHandler.onPointerMove(event as PointerMoveEvent);
                      } else if (toolState.activeTool == ToolType.lasso) {
                        lassoInputHandler.onPointerMove(event as PointerMoveEvent);
                      } else if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
                        ref.read(canvasStateProvider(currentIndex).notifier).eraseAtPoint(point, toolState.size * 2);
                        _triggerAutosave();
                      } else {
                        ref.read(canvasStateProvider(currentIndex).notifier).addPoint(point);
                      }
                    },
                    onPointerUp: (event, point) {
                      if (toolState.activeTool == ToolType.shape) {
                        shapeInputHandler.onPointerUp(event as PointerUpEvent);
                      } else if (toolState.activeTool == ToolType.lasso) {
                        lassoInputHandler.onPointerUp(event as PointerUpEvent);
                      } else if (!toolState.isEraser || toolState.eraserType == EraserType.pixel) {
                        ref.read(canvasStateProvider(currentIndex).notifier).finishStroke(
                              toolState.color,
                              toolState.size,
                              toolState.opacity,
                              isEraser: toolState.isEraser,
                            );
                        
                        final strokes = ref.read(canvasStateProvider(currentIndex)).completedStrokes;
                        if (strokes.isNotEmpty) {
                          final command = StrokeAddCommand(
                            canvasNotifier: ref.read(canvasStateProvider(currentIndex).notifier),
                            stroke: strokes.last,
                          );
                          ref.read(undoRedoProvider(currentIndex).notifier).push(command);
                        }
                        
                        _triggerAutosave();
                      }
                    },
                    child: CanvasWidget(
                      completedStrokes: canvasState.completedStrokes,
                      currentStrokePoints: canvasState.currentStrokePoints,
                      currentStrokeColor: toolState.color,
                      currentStrokeSize: toolState.size,
                      currentStrokeOpacity: toolState.opacity,
                      importedContentState: importedState,
                      isEraser: toolState.isEraser,
                      templateType: toolState.template,
                      shapes: shapeState.shapes,
                      selectionState: selectionState,
                      lassoPreviewPath: lassoPreviewPath,
                    ),
                  ),
                  FreeImageOverlay(notebookId: widget.notebookId, pageIndex: currentIndex),
                  app_sel.SelectionOverlay(pageIndex: currentIndex),
                  if (activeTextBox != null || textBoxRect != null)
                    TextBoxOverlay(
                      pageIndex: currentIndex,
                      existingShape: activeTextBox,
                      initialRect: textBoxRect,
                      colorValue: toolState.color.value,
                      onCommit: () {
                        ref.read(activeTextBoxProvider.notifier).state = null;
                        ref.read(textBoxRectProvider.notifier).state = null;
                      },
                    ),
                  const ShapeToolbar(),
                  ToolBar(notebookId: widget.notebookId, pageIndex: currentIndex),
                ],
              ),
            ),
            PageNavigatorWidget(notebookId: widget.notebookId),
          ],
        ),
      ),
    );
  }
}
