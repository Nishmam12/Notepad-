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
import '../../data/storage/page_cache_manager.dart';
import '../../data/storage/thumbnail_cache_manager.dart';
import '../shape_notifier.dart';
import '../../domain/models/shape_element.dart';
import '../../data/repositories/shape_repository.dart';
import '../../domain/services/autosave_manager.dart';
import '../../../home/presentation/home_notifier.dart';

// Family provider to track the active page index (the one last drawn/touched on) in the book view.
final activeBookPageIndexProvider = StateProvider.family<int, int>((ref, notebookId) => -1);

class BookViewScreen extends ConsumerStatefulWidget {
  final int notebookId;

  const BookViewScreen({super.key, required this.notebookId});

  @override
  ConsumerState<BookViewScreen> createState() => _BookViewScreenState();
}

class _BookViewScreenState extends ConsumerState<BookViewScreen> with WidgetsBindingObserver {
  final PageCacheManager _cacheManager = PageCacheManager();
  final AutosaveManager _autosaveManager = AutosaveManager();
  Timer? _autosaveTimer;
  bool _isSaving = false;
  Color _resolvedBackgroundColor = Colors.white;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _autosaveManager.initialize(widget.notebookId);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final notebook = await ref.read(noteRepositoryProvider).getNotebook(widget.notebookId);
      if (mounted && notebook != null) {
        setState(() {
          _resolvedBackgroundColor = Color(notebook.backgroundColor);
        });
      }

      ref.read(pageProvider(widget.notebookId).notifier).initialize().then((_) {
        final totalPages = ref.read(pageProvider(widget.notebookId)).pages.length;
        ref.read(bookViewProvider(widget.notebookId).notifier).updateTotalPages(totalPages);
        _loadCurrentSpread(0, {}, {}, saveOldSpread: false);
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.inactive) {
      final pageState = ref.read(pageProvider(widget.notebookId));
      final totalPages = pageState.pages.length;
      if (totalPages > 0) {
        final targetSpread = ref.read(bookViewProvider(widget.notebookId)).currentSpread;
        final spreadPages = ref.read(bookViewProvider(widget.notebookId).notifier).calculateSpreadPages(targetSpread);
        for (final pageIndex in spreadPages) {
          if (pageIndex >= 0 && pageIndex < totalPages) {
            _autosaveManager.forceSaveSync(
              notebookId: widget.notebookId,
              pageIndex: pageIndex,
              strokes: ref.read(canvasStateProvider(pageIndex)).completedStrokes,
              shapes: ref.read(shapeProvider(pageIndex)).shapes,
              shapeRepo: ShapeRepository(),
              pageRepo: ref.read(pageRepositoryProvider),
            );
          }
        }
      }
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

    final targetSpread = overrideSpread ?? ref.read(bookViewProvider(widget.notebookId)).currentSpread;
    final spreadPages = ref.read(bookViewProvider(widget.notebookId).notifier).calculateSpreadPages(targetSpread);

    final size = MediaQuery.of(context).size;

    for (final pageIndex in spreadPages) {
      if (pageIndex >= 0 && pageIndex < totalPages) {
        final strokes = overrideStrokes?[pageIndex] ?? ref.read(canvasStateProvider(pageIndex)).completedStrokes;
        final shapes = overrideShapes?[pageIndex] ?? ref.read(shapeProvider(pageIndex)).shapes;
        final importedState = ref.read(importedContentProvider(pageIndex));
        
        await _autosaveManager.forceSaveAsync(
          notebookId: widget.notebookId,
          pageIndex: pageIndex,
          strokes: strokes,
          shapes: shapes,
          contents: importedState.contents,
          loadedImages: importedState.loadedImages,
          screenSize: size,
          shapeRepo: ShapeRepository(),
          pageRepo: ref.read(pageRepositoryProvider),
          onSaveComplete: () {
            ThumbnailCacheManager.invalidate(widget.notebookId, pageIndex);
          },
        );
      }
    }

    _isSaving = false;
  }

  Future<void> _loadCurrentSpread(int oldSpread, Map<int, List<Stroke>> oldStrokes, Map<int, List<ShapeElement>> oldShapes, {bool saveOldSpread = true}) async {
    // Skip the save on the initial mount: the spread's pages have not been loaded
    // into the providers yet, so saving would overwrite their stored data with
    // empty strokes/shapes and erase the user's drawings.
    if (saveOldSpread) {
      await _forceSave(overrideSpread: oldSpread, overrideStrokes: oldStrokes, overrideShapes: oldShapes);
    }

    final pageState = ref.read(pageProvider(widget.notebookId));
    final totalPages = pageState.pages.length;
    if (totalPages == 0) return;

    final spreadPages = ref.read(bookViewProvider(widget.notebookId).notifier).pagesForSpread;

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

    ref.listen<BookViewState>(bookViewProvider(widget.notebookId), (previous, next) {
      if (previous != null && previous.currentSpread != next.currentSpread) {
        // Read old strokes synchronously before the autoDispose provider is destroyed
        final oldSpreadPages = ref.read(bookViewProvider(widget.notebookId).notifier).calculateSpreadPages(previous.currentSpread);
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

    final bookViewState = ref.watch(bookViewProvider(widget.notebookId));
    final spreadPages = ref.read(bookViewProvider(widget.notebookId).notifier).calculateSpreadPages(bookViewState.currentSpread);
    final leftPage = spreadPages[0];
    final rightPage = spreadPages[1];

    final hasLeft = leftPage >= 0 && leftPage < totalPages;
    final hasRight = rightPage >= 0 && rightPage < totalPages;

    final activePageIndex = ref.watch(activeBookPageIndexProvider(widget.notebookId));
    int resolvedActivePageIndex = activePageIndex;
    if (!spreadPages.contains(activePageIndex)) {
      resolvedActivePageIndex = hasLeft ? leftPage : (hasRight ? rightPage : 0);
    }

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
          elevation: 0,
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
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: Stack(
          children: [
            Column(
              children: [
                BookSpreadNavBar(notebookId: widget.notebookId),
                Expanded(
                  child: totalPages == 0
                      ? const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                          ),
                        )
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                transitionBuilder: (Widget child, Animation<double> animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: child,
                                  );
                                },
                                child: LayoutBuilder(
                                  key: ValueKey(bookViewState.currentSpread),
                                  builder: (context, constraints) {
                              final workspaceWidth = constraints.maxWidth - 48;
                              final workspaceHeight = constraints.maxHeight - 48;

                              if (workspaceWidth <= 0 || workspaceHeight <= 0) {
                                return const SizedBox.shrink();
                              }

                              final isDoublePage = hasLeft && hasRight;
                              final targetAspectRatio = isDoublePage ? 1.414 : 0.707;

                              double bookWidth, bookHeight;
                              if (workspaceWidth / workspaceHeight > targetAspectRatio) {
                                bookHeight = workspaceHeight;
                                bookWidth = workspaceHeight * targetAspectRatio;
                              } else {
                                bookWidth = workspaceWidth;
                                bookHeight = workspaceWidth / targetAspectRatio;
                              }

                              return Center(
                                child: Container(
                                  width: bookWidth,
                                  height: bookHeight,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        Color(0xFF4A3628),   // warm espresso top-left
                                        Color(0xFF2E2018),   // deeper cocoa bottom-right
                                      ],
                                    ),
                                    borderRadius: const BorderRadius.only(
                                      topLeft: Radius.circular(4),
                                      bottomLeft: Radius.circular(4),
                                      topRight: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.shadowTint.withValues(alpha: 0.45),
                                        blurRadius: 40,
                                        spreadRadius: 4,
                                        offset: const Offset(0, 16),
                                      ),
                                      BoxShadow(
                                        color: AppColors.shadowTint.withValues(alpha: 0.28),
                                        blurRadius: 12,
                                        offset: const Offset(4, 8),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.fromLTRB(12, 10, 10, 12), // asymmetric
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: isDoublePage
                                        ? Row(
                                            children: [
                                              Expanded(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.25),
                                                        blurRadius: 8,
                                                        offset: const Offset(-2, 0),
                                                      ),
                                                    ],
                                                  ),
                                                  child: EditablePagePane(
                                                    pageIndex: leftPage,
                                                    notebookId: widget.notebookId,
                                                    backgroundColor: _resolvedBackgroundColor,
                                                    totalPages: totalPages,
                                                    onAutosaveTriggered: _triggerAutosave,
                                                  ),
                                                ),
                                              ),
                                              // spine shadow/gradient
                                              Container(
                                                width: 32,
                                                decoration: const BoxDecoration(
                                                  gradient: LinearGradient(
                                                    begin: Alignment.centerLeft,
                                                    end: Alignment.centerRight,
                                                    colors: [
                                                      Color(0xFF211208),         // deep shadow on left page edge
                                                      Color(0xFF4A3628),         // warm spine surface
                                                      Color(0xFF6E5544),         // spine highlight centre
                                                      Color(0xFF4A3628),         // warm spine surface
                                                      Color(0xFF211208),         // deep shadow on right page edge
                                                    ],
                                                    stops: [0.0, 0.15, 0.5, 0.85, 1.0],
                                                  ),
                                                ),
                                              ),
                                              Expanded(
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black.withValues(alpha: 0.25),
                                                        blurRadius: 8,
                                                        offset: const Offset(2, 0),
                                                      ),
                                                    ],
                                                  ),
                                                  child: EditablePagePane(
                                                    pageIndex: rightPage,
                                                    notebookId: widget.notebookId,
                                                    backgroundColor: _resolvedBackgroundColor,
                                                    totalPages: totalPages,
                                                    onAutosaveTriggered: _triggerAutosave,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          )
                                        : Center(
                                            child: SizedBox(
                                              width: bookWidth - 16,
                                              height: bookHeight - 16,
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black.withValues(alpha: 0.25),
                                                      blurRadius: 8,
                                                      offset: const Offset(2, 0),
                                                    ),
                                                  ],
                                                ),
                                                child: EditablePagePane(
                                                  pageIndex: hasRight ? rightPage : leftPage,
                                                  notebookId: widget.notebookId,
                                                  backgroundColor: _resolvedBackgroundColor,
                                                  totalPages: totalPages,
                                                  onAutosaveTriggered: _triggerAutosave,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ),
                                  );
                                },
                              ),
                            ),
                          ),
                            // Left Edge Tap Zone
                            Positioned(
                              left: 0,
                              top: 0,
                              bottom: 0,
                              width: MediaQuery.of(context).size.width * 0.1,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => ref.read(bookViewProvider(widget.notebookId).notifier).previousSpread(),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            // Right Edge Tap Zone
                            Positioned(
                              right: 0,
                              top: 0,
                              bottom: 0,
                              width: MediaQuery.of(context).size.width * 0.1,
                              child: GestureDetector(
                                behavior: HitTestBehavior.translucent,
                                onTap: () => ref.read(bookViewProvider(widget.notebookId).notifier).nextSpread(),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
            if (totalPages > 0)
              ToolBar(
                notebookId: widget.notebookId,
                pageIndex: resolvedActivePageIndex,
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
  final Color backgroundColor;
  final VoidCallback onAutosaveTriggered;

  const EditablePagePane({
    super.key,
    required this.pageIndex,
    required this.notebookId,
    required this.backgroundColor,
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
            // Set this page as the active page for tool operations
            ref.read(activeBookPageIndexProvider(notebookId).notifier).state = pageIndex;

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
          child: Container(
            color: backgroundColor,
            child: CanvasWidget(
              completedStrokes: canvasState.completedStrokes,
              currentStrokePoints: canvasState.currentStrokePoints,
              currentStrokeColor: toolState.color,
              currentStrokeSize: toolState.size,
              currentStrokeOpacity: toolState.opacity,
              importedContentState: importedState,
              isEraser: toolState.isEraser,
              templateType: toolState.template,
              backgroundColor: backgroundColor,
              shapes: shapeState.shapes,
              pageIndex: pageIndex,
            ),
          ),
        ),
        FreeImageOverlay(notebookId: notebookId, pageIndex: pageIndex),
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.textPrimary.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Page ${pageIndex + 1}',
              style: const TextStyle(
                fontFamily: 'Poppins',
                color: AppColors.surface,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
