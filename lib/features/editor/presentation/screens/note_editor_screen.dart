// Full-screen editor screen with canvas, toolbar, page navigation, and stroke persistence.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../canvas_notifier.dart';
import '../viewport_notifier.dart';
import '../../domain/models/stroke.dart';
import '../../domain/models/stroke_point.dart';
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
import '../../data/storage/page_cache_manager.dart';
import '../../data/storage/thumbnail_cache_manager.dart';
import '../../domain/services/autosave_manager.dart';
import '../../data/repositories/shape_repository.dart';
import '../../domain/models/shape_type.dart';
import '../../domain/models/shape_element.dart';
import '../../domain/models/template_type.dart';
import '../widgets/template_picker.dart';
import '../../domain/services/shape_geometry.dart';
import '../shape_notifier.dart';
import '../selection_notifier.dart';
import '../eraser_notifier.dart';
import '../../domain/services/eraser_service.dart';
import '../../domain/undo_redo/lasso_delete_command.dart';
import '../../domain/undo_redo/shape_add_command.dart';
import '../canvas/input/shape_input_handler.dart';
import '../canvas/input/lasso_input_handler.dart';
import '../../domain/services/lasso_hit_tester.dart';
import '../widgets/shape_toolbar.dart';
import '../widgets/shape_style_panel.dart';
import '../widgets/selection_overlay.dart' as app_sel;
import '../widgets/text_box_overlay.dart';
import '../widgets/text_element_overlay.dart';
import '../../../home/presentation/home_notifier.dart';

final lassoPreviewProvider = StateProvider.autoDispose<List<Offset>>((ref) => []);
final activeTextBoxProvider = StateProvider.autoDispose<ShapeElement?>((ref) => null);
final textBoxRectProvider = StateProvider.autoDispose<Rect?>((ref) => null);

/// Live preview of the shape currently being dragged (null when idle).
final shapePreviewProvider = StateProvider.autoDispose<ShapeElement?>((ref) => null);

class NoteEditorScreen extends ConsumerStatefulWidget {
  final int notebookId;

  const NoteEditorScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> with WidgetsBindingObserver {
  final PageCacheManager _cacheManager = PageCacheManager();
  final AutosaveManager _autosaveManager = AutosaveManager();

  late final ShapeInputHandler _shapeInputHandler;
  late final LassoInputHandler _lassoInputHandler;
  Color _backgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autosaveManager.initialize(widget.notebookId);

    _shapeInputHandler = ShapeInputHandler(
      onShapeRecognised: (ShapeElement shape) {
        final currentIndex = ref.read(pageProvider(widget.notebookId)).currentPageIndex;
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
        final currentIndex = ref.read(pageProvider(widget.notebookId)).currentPageIndex;
        final toolState = ref.read(toolProvider);
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
      getToolState: () => ref.read(toolProvider),
      onPreviewUpdate: (preview) {
        ref.read(shapePreviewProvider.notifier).state = preview;
      },
      getCurrentShapes: () => ref
          .read(shapeProvider(ref.read(pageProvider(widget.notebookId)).currentPageIndex))
          .shapes,
    );

    _lassoInputHandler = LassoInputHandler(
      onLassoComplete: (LassoHitResult result, Rect bounds) {
        ref.read(selectionProvider.notifier).setSelection(result, bounds);
      },
      onLassoUpdate: (List<Offset> path) {
        ref.read(lassoPreviewProvider.notifier).state = path;
      },
      getCurrentStrokes: () => ref.read(canvasStateProvider(ref.read(pageProvider(widget.notebookId)).currentPageIndex)).completedStrokes,
      getCurrentShapes: () => ref.read(shapeProvider(ref.read(pageProvider(widget.notebookId)).currentPageIndex)).shapes,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notebook = await ref.read(noteRepositoryProvider).getNotebook(widget.notebookId);
      if (mounted && notebook != null) {
        setState(() {
          _backgroundColor = Color(notebook.backgroundColor);
        });
        // Restore this notebook's saved page/paper style.
        const templates = TemplateType.values;
        final index = notebook.templateIndex.clamp(0, templates.length - 1);
        ref.read(toolProvider.notifier).setTemplate(templates[index]);
      }

      ref.read(pageProvider(widget.notebookId).notifier).initialize().then((_) {
        _performPageSwitchLoad(0, 0, [], [], saveOldPage: false);
        ref.read(importedContentProvider(0).notifier).loadForPage(widget.notebookId);
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autosaveManager.dispose();
    _forceSave();
    _cacheManager.clear();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      final pageState = ref.read(pageProvider(widget.notebookId));
      if (pageState.pages.isNotEmpty) {
        final currentIndex = pageState.currentPageIndex;
        _autosaveManager.forceSaveSync(
          notebookId: widget.notebookId,
          pageIndex: currentIndex,
          strokes: ref.read(canvasStateProvider(currentIndex)).completedStrokes,
          shapes: ref.read(shapeProvider(currentIndex)).shapes,
          shapeRepo: ShapeRepository(),
          pageRepo: ref.read(pageRepositoryProvider),
        );
      }
    }
  }

  void _triggerAutosave() {
    final pageState = ref.read(pageProvider(widget.notebookId));
    if (pageState.pages.isEmpty) return;

    final currentIndex = pageState.currentPageIndex;
    final importedState = ref.read(importedContentProvider(currentIndex));

    _autosaveManager.triggerDebouncedSave(
      notebookId: widget.notebookId,
      pageIndex: currentIndex,
      strokes: ref.read(canvasStateProvider(currentIndex)).completedStrokes,
      shapes: ref.read(shapeProvider(currentIndex)).shapes,
      contents: importedState.contents,
      loadedImages: importedState.loadedImages,
      screenSize: MediaQuery.of(context).size,
      shapeRepo: ShapeRepository(),
      pageRepo: ref.read(pageRepositoryProvider),
      onSaveComplete: () {
        ThumbnailCacheManager.invalidate(widget.notebookId, currentIndex);
      },
    );
  }

  Future<void> _forceSave({int? pageIndexOverride, List<Stroke>? strokesOverride, List<ShapeElement>? shapesOverride}) async {
    final pageState = ref.read(pageProvider(widget.notebookId));
    if (pageState.pages.isEmpty) return;

    final currentIndex = pageIndexOverride ?? pageState.currentPageIndex;
    final strokes = strokesOverride ?? ref.read(canvasStateProvider(currentIndex)).completedStrokes;
    final shapes = shapesOverride ?? ref.read(shapeProvider(currentIndex)).shapes;
    final importedState = ref.read(importedContentProvider(currentIndex));

    await _autosaveManager.forceSaveAsync(
      notebookId: widget.notebookId,
      pageIndex: currentIndex,
      strokes: strokes,
      shapes: shapes,
      contents: importedState.contents,
      loadedImages: importedState.loadedImages,
      screenSize: MediaQuery.of(context).size,
      shapeRepo: ShapeRepository(),
      pageRepo: ref.read(pageRepositoryProvider),
      onSaveComplete: () {
        ThumbnailCacheManager.invalidate(widget.notebookId, currentIndex);
      },
    );
  }

  Future<void> _performPageSwitchLoad(int oldPageIndex, int newPageIndex, List<Stroke> oldStrokes, List<ShapeElement> oldShapes, {bool saveOldPage = true}) async {
    if (saveOldPage) {
      await _forceSave(pageIndexOverride: oldPageIndex, strokesOverride: oldStrokes, shapesOverride: oldShapes);
    }

    ref.read(canvasStateProvider(newPageIndex).notifier).loadStrokes([]);
    ref.read(shapeProvider(newPageIndex).notifier).clearShapes();

    final pageData = await _cacheManager.getPage(widget.notebookId, newPageIndex);

    if (mounted) {
      ref.read(canvasStateProvider(newPageIndex).notifier).loadStrokes(pageData.strokes);
      ref.read(importedContentProvider(newPageIndex).notifier).loadForPage(widget.notebookId);
      ref.read(shapeProvider(newPageIndex).notifier).loadForPage(widget.notebookId);
    }

    _cacheManager.preloadAdjacent(widget.notebookId, newPageIndex);
  }

  // Previous stroke-eraser position (scene space); paired with the current
  // point to form the segment tested each move so fast swipes skip nothing.
  Offset? _lastEraseScene;

  /// Begins a stroke-eraser gesture: clears any prior marks/trail.
  void _beginErase(StrokePoint scenePoint, int pageIndex, double radius) {
    _lastEraseScene = null;
    ref.read(pendingEraseProvider.notifier).clear();
    ref.read(eraserTrailProvider.notifier).clear();
    _eraseAlong(scenePoint, pageIndex, radius);
  }

  /// Marks (does not delete) strokes/shapes the eraser segment crosses, dims
  /// them via [pendingEraseProvider], and extends the animated trail.
  void _eraseAlong(StrokePoint scenePoint, int pageIndex, double radius) {
    final cur = scenePoint.toOffset();
    final prev = _lastEraseScene ?? cur;
    _lastEraseScene = cur;

    final pending = ref.read(pendingEraseProvider);
    final (strokeIds, shapeIds) = EraserService.hitAlongSegment(
      a: prev,
      b: cur,
      radius: radius,
      strokes: ref.read(canvasStateProvider(pageIndex)).completedStrokes,
      shapes: ref.read(shapeProvider(pageIndex)).shapes,
      skipStrokeIds: pending.strokeIds,
      skipShapeIds: pending.shapeIds,
    );
    ref.read(pendingEraseProvider.notifier).addHits(strokeIds, shapeIds);
    ref.read(eraserTrailProvider.notifier).addPoint(cur);
  }

  /// Commits the stroke-eraser gesture as a single undoable delete.
  void _commitErase(int pageIndex) {
    _lastEraseScene = null;
    ref.read(eraserTrailProvider.notifier).clear();

    final pending = ref.read(pendingEraseProvider);
    if (pending.isEmpty) return;

    final strokes = ref.read(canvasStateProvider(pageIndex)).completedStrokes;
    final shapes = ref.read(shapeProvider(pageIndex)).shapes;
    final deletedStrokes =
        strokes.where((s) => pending.strokeIds.contains(s.id)).toList();
    final deletedShapes =
        shapes.where((s) => pending.shapeIds.contains(s.id)).toList();

    final command = LassoDeleteCommand(
      canvasNotifier: ref.read(canvasStateProvider(pageIndex).notifier),
      shapeNotifier: ref.read(shapeProvider(pageIndex).notifier),
      deletedStrokes: deletedStrokes,
      deletedShapes: deletedShapes,
    );
    ref.read(undoRedoProvider(pageIndex).notifier).push(command);
    command.execute();

    ref.read(pendingEraseProvider.notifier).clear();
    _triggerAutosave();
  }

  /// Cancels an in-progress stroke-erase without deleting anything.
  void _cancelErase() {
    _lastEraseScene = null;
    ref.read(pendingEraseProvider.notifier).clear();
    ref.read(eraserTrailProvider.notifier).clear();
  }

  /// Convert a raw screen-space StrokePoint to scene coordinates using the current viewport.
  StrokePoint _toScene(StrokePoint raw, ViewportState vp) {
    final scene = vp.toScene(Offset(raw.x, raw.y));
    return StrokePoint(
      x: scene.dx,
      y: scene.dy,
      pressure: raw.pressure,
      simulatePressure: raw.simulatePressure,
    );
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
    final pendingErase = ref.watch(pendingEraseProvider);
    final lassoPreviewPath = ref.watch(lassoPreviewProvider);
    final shapePreview = ref.watch(shapePreviewProvider);
    final activeTextBox = ref.watch(activeTextBoxProvider);
    final textBoxRect = ref.watch(textBoxRectProvider);
    final viewport = ref.watch(viewportProvider);

    ref.listen<PageState>(pageProvider(widget.notebookId), (previous, next) {
      if (previous != null && previous.currentPageIndex != next.currentPageIndex) {
        final oldStrokes = ref.read(canvasStateProvider(previous.currentPageIndex)).completedStrokes;
        final oldShapes = ref.read(shapeProvider(previous.currentPageIndex)).shapes;
        _performPageSwitchLoad(previous.currentPageIndex, next.currentPageIndex, oldStrokes, oldShapes);
      }
    });

    final isTablet = MediaQuery.of(context).size.width > 600;

    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) _forceSave();
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
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          actions: [
            // Reset zoom/pan button — appears when viewport is not at 1:1
            if (viewport.zoom != 1.0 || viewport.scrollX != 0.0 || viewport.scrollY != 0.0)
              IconButton(
                icon: const Icon(Icons.zoom_out_map),
                tooltip: 'Reset View',
                onPressed: () => ref.read(viewportProvider.notifier).reset(),
              ),
            IconButton(
              icon: const Icon(Icons.dashboard_customize_outlined),
              tooltip: 'Page Style',
              onPressed: () => showTemplatePicker(
                context: context,
                ref: ref,
                notebookId: widget.notebookId,
                currentColor: _backgroundColor,
                onColorChanged: (color) {
                  setState(() => _backgroundColor = color);
                  ref.read(noteRepositoryProvider).updateBackgroundColor(widget.notebookId, color.toARGB32());
                },
                onTemplateChanged: (type) {
                  ref.read(noteRepositoryProvider).updateTemplateIndex(widget.notebookId, type.index);
                },
              ),
            ),
            IconButton(
              icon: const Icon(Icons.menu_book),
              tooltip: 'Book View',
              onPressed: () {
                _forceSave().then((_) {
                  if (!context.mounted) return;
                  context.push('/note/${widget.notebookId}/book');
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
        body: Flex(
          direction: isTablet ? Axis.horizontal : Axis.vertical,
          children: [
            Expanded(
              child: Stack(
                children: [
                  RawPointerListener(
                    enablePalmRejection: true,
                    isHandTool: toolState.activeTool == ToolType.hand,
                    onStrokeCancel: () {
                      // Second pointer arrived mid-stroke — discard the in-flight stroke.
                      ref.read(canvasStateProvider(currentIndex).notifier).clearCurrentStroke();
                      // Also abandon any in-progress stroke-erase (don't delete).
                      _cancelErase();
                    },
                    onViewportUpdate: (panDelta, focalPoint, scaleDelta) {
                      final notifier = ref.read(viewportProvider.notifier);
                      if (panDelta != Offset.zero) {
                        notifier.pan(panDelta);
                      }
                      if (scaleDelta != 1.0) {
                        notifier.zoomAtPoint(
                          ref.read(viewportProvider).zoom * scaleDelta,
                          focalPoint,
                        );
                      }
                    },
                    onPointerDown: (event, point) {
                      final scenePoint = _toScene(point, viewport);
                      if (toolState.activeTool == ToolType.shape) {
                        _shapeInputHandler.onPointerDown(scenePoint);
                      } else if (toolState.activeTool == ToolType.lasso) {
                        _lassoInputHandler.onPointerDown(scenePoint.toOffset());
                      } else if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
                        _beginErase(scenePoint, currentIndex, toolState.size * 2);
                      } else {
                        ref.read(canvasStateProvider(currentIndex).notifier).addPoint(scenePoint);
                      }
                    },
                    onPointerMove: (event, point) {
                      final scenePoint = _toScene(point, viewport);
                      if (toolState.activeTool == ToolType.shape) {
                        _shapeInputHandler.onPointerMove(scenePoint);
                      } else if (toolState.activeTool == ToolType.lasso) {
                        _lassoInputHandler.onPointerMove(scenePoint.toOffset());
                      } else if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
                        _eraseAlong(scenePoint, currentIndex, toolState.size * 2);
                      } else {
                        ref.read(canvasStateProvider(currentIndex).notifier).addPoint(scenePoint);
                      }
                    },
                    onPointerUp: (event, point) {
                      final scenePoint = _toScene(point, viewport);
                      if (toolState.activeTool == ToolType.shape) {
                        _shapeInputHandler.onPointerUp(scenePoint);
                      } else if (toolState.activeTool == ToolType.lasso) {
                        _lassoInputHandler.onPointerUp(scenePoint.toOffset());
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
                      } else if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
                        // Commit the whole stroke-erase gesture as one undo step.
                        _commitErase(currentIndex);
                      }
                    },
                    child: Container(
                      color: _backgroundColor,
                      // Apply viewport transform so the canvas pans/zooms visually.
                      child: Transform(
                        transform: viewport.toMatrix4(),
                        child: CanvasWidget(
                          completedStrokes: canvasState.completedStrokes,
                          currentStrokePoints: canvasState.currentStrokePoints,
                          currentStrokeColor: toolState.color,
                          currentStrokeSize: toolState.size,
                          currentStrokeOpacity: toolState.opacity,
                          importedContentState: importedState,
                          isEraser: toolState.isEraser && toolState.eraserType == EraserType.pixel,
                          templateType: toolState.template,
                          backgroundColor: _backgroundColor,
                          shapes: shapeState.shapes,
                          previewShape: shapePreview,
                          selectionState: selectionState,
                          lassoPreviewPath: lassoPreviewPath,
                          pageIndex: currentIndex,
                          pendingEraseStrokeIds: pendingErase.strokeIds,
                          pendingEraseShapeIds: pendingErase.shapeIds,
                          showEraserTrail: toolState.isEraser &&
                              toolState.eraserType == EraserType.stroke,
                        ),
                      ),
                    ),
                  ),
                  FreeImageOverlay(notebookId: widget.notebookId, pageIndex: currentIndex),
                  TextElementOverlay(
                    pageIndex: currentIndex,
                    enabled: toolState.activeTool == ToolType.lasso,
                    onEdit: (shape) {
                      ref.read(activeTextBoxProvider.notifier).state = shape;
                    },
                    onChanged: _triggerAutosave,
                  ),
                  app_sel.SelectionOverlay(pageIndex: currentIndex),
                  ShapeStylePanel(
                    pageIndex: currentIndex,
                    onChanged: _triggerAutosave,
                  ),
                  if (activeTextBox != null || textBoxRect != null)
                    TextBoxOverlay(
                      pageIndex: currentIndex,
                      existingShape: activeTextBox,
                      initialRect: textBoxRect,
                      colorValue: toolState.color.toARGB32(),
                      onCommit: () {
                        ref.read(activeTextBoxProvider.notifier).state = null;
                        ref.read(textBoxRectProvider.notifier).state = null;
                      },
                    ),
                  const ShapeToolbar(),
                  ToolBar(
                    notebookId: widget.notebookId,
                    pageIndex: currentIndex,
                  ),
                ],
              ),
            ),
            isTablet
                ? const VerticalDivider(width: 1, thickness: 1, color: AppColors.border)
                : const Divider(height: 1, thickness: 1, color: AppColors.border),
            PageNavigatorWidget(
              notebookId: widget.notebookId,
              direction: isTablet ? Axis.vertical : Axis.horizontal,
            ),
          ],
        ),
      ),
    );
  }
}
