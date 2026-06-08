import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../domain/models/stroke.dart';
import '../canvas_notifier.dart';
import '../page_notifier.dart';
import '../book_view_notifier.dart';
import '../canvas/canvas_widget.dart';
import '../canvas/input/raw_pointer_listener.dart';
import '../widgets/tool_bar.dart';
import '../widgets/book_spread_nav_bar.dart';
import '../widgets/free_image_overlay.dart';
import '../imported_content_notifier.dart';
import '../../domain/undo_redo/undo_redo_stack.dart';
import '../../domain/undo_redo/stroke_add_command.dart';
import '../../data/storage/ink_file_storage.dart';
import '../../data/storage/page_cache_manager.dart';
import '../../data/storage/page_thumbnail_service.dart';
import '../shape_notifier.dart';
import '../../domain/models/shape_element.dart';
import '../../data/repositories/shape_repository.dart';

class BookViewScreen extends ConsumerStatefulWidget {
  final int notebookId;

  const BookViewScreen({super.key, required this.notebookId});

  @override
  ConsumerState<BookViewScreen> createState() => _BookViewScreenState();
}

class _BookViewScreenState extends ConsumerState<BookViewScreen> with WidgetsBindingObserver {
  final PageCacheManager _cacheManager = PageCacheManager();
  Timer? _autosaveTimer;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pageProvider(widget.notebookId).notifier).initialize().then((_) {
        final totalPages = ref.read(pageProvider(widget.notebookId)).pages.length;
        ref.read(bookViewProvider(totalPages).notifier).updateTotalPages(totalPages);
        _loadCurrentSpread(0, {}, {});
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

  Future<void> _forceSave({int? overrideSpread, Map<int, List<Stroke>>? overrideStrokes, Map<int, List<ShapeElement>>? overrideShapes}) async {
    if (_isSaving) return;
    _isSaving = true;

    final pageState = ref.read(pageProvider(widget.notebookId));
    final totalPages = pageState.pages.length;
    if (totalPages == 0) {
      _isSaving = false;
      return;
    }

    final targetSpread = overrideSpread ?? ref.read(bookViewProvider(totalPages)).currentSpread;
    final spreadPages = ref.read(bookViewProvider(totalPages).notifier).calculateSpreadPages(targetSpread);

    final size = MediaQuery.of(context).size;

    for (final pageIndex in spreadPages) {
      if (pageIndex >= 0 && pageIndex < totalPages) {
        final strokes = overrideStrokes?[pageIndex] ?? ref.read(canvasStateProvider(pageIndex)).completedStrokes;
        final shapes = overrideShapes?[pageIndex] ?? ref.read(shapeProvider(pageIndex)).shapes;
        final importedState = ref.read(importedContentProvider(pageIndex));
        
        await InkFileStorage.saveStrokes(
          notebookId: widget.notebookId,
          pageId: pageIndex,
          strokes: strokes,
        );
        await ShapeRepository().saveShapesForPage(widget.notebookId, pageIndex, shapes);
        
        PageThumbnailService.generateAndSave(
          widget.notebookId, 
          pageIndex, 
          strokes, 
          importedState.contents,
          importedState.loadedImages,
          shapes,
          size,
        );
      }
    }

    _isSaving = false;
  }

  Future<void> _loadCurrentSpread(int oldSpread, Map<int, List<Stroke>> oldStrokes, Map<int, List<ShapeElement>> oldShapes) async {
    await _forceSave(overrideSpread: oldSpread, overrideStrokes: oldStrokes, overrideShapes: oldShapes);

    final pageState = ref.read(pageProvider(widget.notebookId));
    final totalPages = pageState.pages.length;
    if (totalPages == 0) return;

    final spreadPages = ref.read(bookViewProvider(totalPages).notifier).pagesForSpread;

    for (final pageIndex in spreadPages) {
      if (pageIndex >= 0 && pageIndex < totalPages) {
        ref.read(canvasStateProvider(pageIndex).notifier).loadStrokes([]);
        ref.read(shapeProvider(pageIndex).notifier).clearShapes();
        ref.read(importedContentProvider(pageIndex).notifier).loadForPage(widget.notebookId);
        ref.read(shapeProvider(pageIndex).notifier).loadForPage(widget.notebookId);
        final pageData = await _cacheManager.getPage(widget.notebookId, pageIndex);
        if (mounted) {
          ref.read(canvasStateProvider(pageIndex).notifier).loadStrokes(pageData.strokes);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(pageProvider(widget.notebookId));
    final totalPages = pageState.pages.length;

    ref.listen<BookViewState>(bookViewProvider(totalPages), (previous, next) {
      if (previous != null && previous.currentSpread != next.currentSpread) {
        // Read old strokes synchronously before the autoDispose provider is destroyed
        final oldSpreadPages = ref.read(bookViewProvider(totalPages).notifier).calculateSpreadPages(previous.currentSpread);
        final oldStrokes = <int, List<Stroke>>{};
        final oldShapes = <int, List<ShapeElement>>{};
        for (final p in oldSpreadPages) {
          if (p >= 0 && p < totalPages) {
            oldStrokes[p] = ref.read(canvasStateProvider(p)).completedStrokes;
            oldShapes[p] = ref.read(shapeProvider(p)).shapes;
          }
        }
        _loadCurrentSpread(previous.currentSpread, oldStrokes, oldShapes);
      }
    });

    final spreadPages = ref.read(bookViewProvider(totalPages).notifier).pagesForSpread;
    final leftPage = spreadPages[0];
    final rightPage = spreadPages[1];

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
            'Book View',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
        body: Column(
          children: [
            BookSpreadNavBar(totalPages: totalPages),
            Expanded(
              child: GestureDetector(
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity != null) {
                    if (details.primaryVelocity! > 300) {
                      ref.read(bookViewProvider(totalPages).notifier).previousSpread();
                    } else if (details.primaryVelocity! < -300) {
                      ref.read(bookViewProvider(totalPages).notifier).nextSpread();
                    }
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: EditablePagePane(
                        pageIndex: leftPage,
                        notebookId: widget.notebookId,
                        totalPages: totalPages,
                        onAutosaveTriggered: _triggerAutosave,
                      ),
                    ),
                    Container(width: 2, color: AppColors.border),
                    Expanded(
                      child: EditablePagePane(
                        pageIndex: rightPage,
                        notebookId: widget.notebookId,
                        totalPages: totalPages,
                        onAutosaveTriggered: _triggerAutosave,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditablePagePane extends ConsumerWidget {
  final int pageIndex;
  final int notebookId;
  final int totalPages;
  final VoidCallback onAutosaveTriggered;

  const EditablePagePane({
    super.key,
    required this.pageIndex,
    required this.notebookId,
    required this.totalPages,
    required this.onAutosaveTriggered,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (pageIndex < 0 || pageIndex >= totalPages) {
      return Container(color: AppColors.surface.withValues(alpha: 0.3));
    }

    final canvasState = ref.watch(canvasStateProvider(pageIndex));
    final toolState = ref.watch(toolProvider);
    final importedState = ref.watch(importedContentProvider(pageIndex));
    final shapeState = ref.watch(shapeProvider(pageIndex));

    return Stack(
      children: [
        RawPointerListener(
          onPointerDown: (event, point) {
            if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
              ref.read(canvasStateProvider(pageIndex).notifier).eraseAtPoint(point, toolState.size * 2);
              onAutosaveTriggered();
            } else {
              ref.read(canvasStateProvider(pageIndex).notifier).addPoint(point);
            }
          },
          onPointerMove: (event, point) {
            if (toolState.isEraser && toolState.eraserType == EraserType.stroke) {
              ref.read(canvasStateProvider(pageIndex).notifier).eraseAtPoint(point, toolState.size * 2);
              onAutosaveTriggered();
            } else {
              ref.read(canvasStateProvider(pageIndex).notifier).addPoint(point);
            }
          },
          onPointerUp: (event, point) {
            if (!toolState.isEraser || toolState.eraserType == EraserType.pixel) {
              ref.read(canvasStateProvider(pageIndex).notifier).finishStroke(
                    toolState.color,
                    toolState.size,
                    toolState.opacity,
                    isEraser: toolState.isEraser,
                  );

              final strokes = ref.read(canvasStateProvider(pageIndex)).completedStrokes;
              if (strokes.isNotEmpty) {
                final command = StrokeAddCommand(
                  canvasNotifier: ref.read(canvasStateProvider(pageIndex).notifier),
                  stroke: strokes.last,
                );
                ref.read(undoRedoProvider(pageIndex).notifier).push(command);
              }

              onAutosaveTriggered();
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
          ),
        ),
        FreeImageOverlay(notebookId: notebookId, pageIndex: pageIndex),
        ToolBar(notebookId: notebookId, pageIndex: pageIndex),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Page ${pageIndex + 1}',
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 12),
            ),
          ),
        ),
      ],
    );
  }
}
