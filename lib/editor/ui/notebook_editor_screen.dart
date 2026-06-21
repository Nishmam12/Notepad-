// The real notebook editor on the unified engine (Canvas 2.0). Opens a notebook
// by id, drives page navigation through the existing [pageProvider], and binds
// the unified [SceneCanvas] to the real Isar-backed scene store (so edits load
// and autosave through [SceneElementRecord]). Paper colour + template come from
// the [Notebook]. All chrome is shared with the dev playground.
//
// Reachable from Home when "Canvas 2.0" is enabled in Settings; the legacy
// editor stays intact and is removed only in a later, separately-approved phase.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/editor/domain/models/template_type.dart';
import '../../features/editor/presentation/page_notifier.dart';
import '../../features/home/domain/models/notebook.dart';
import '../../shared/isar/isar_service.dart';
import '../state/library_controller.dart';
import '../state/scene_controller.dart';
import '../state/selection_controller.dart';
import '../state/viewport_controller.dart';
import 'editor_controls.dart';
import 'scene_canvas.dart';

class NotebookEditorScreen extends ConsumerStatefulWidget {
  final int notebookId;
  const NotebookEditorScreen({super.key, required this.notebookId});

  @override
  ConsumerState<NotebookEditorScreen> createState() =>
      _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends ConsumerState<NotebookEditorScreen> {
  final Set<int> _loadedPages = {};
  Notebook? _notebook;

  @override
  void initState() {
    super.initState();
    Future.microtask(_init);
  }

  Future<void> _init() async {
    await ref.read(pageProvider(widget.notebookId).notifier).initialize();
    final nb = await IsarService.instance.notebooks.get(widget.notebookId);
    await ref.read(libraryProvider.notifier).load();
    if (mounted) setState(() => _notebook = nb);
  }

  Color get _paperColor => Color(_notebook?.backgroundColor ?? 0xFFFFFDF7);

  TemplateType get _template {
    final i = _notebook?.templateIndex ?? 0;
    return (i >= 0 && i < TemplateType.values.length)
        ? TemplateType.values[i]
        : TemplateType.blank;
  }

  /// Loads a page's elements from the store once per session.
  void _ensureLoaded(ScenePageKey key) {
    if (_loadedPages.contains(key.pageId)) return;
    _loadedPages.add(key.pageId);
    Future.microtask(
        () => ref.read(sceneControllerProvider(key).notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(pageProvider(widget.notebookId));
    final zoom = ref.watch(viewportProvider.select((v) => v.zoom));

    if (pageState.pages.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final index = pageState.currentPageIndex.clamp(0, pageState.pages.length - 1);
    final page = pageState.pages[index];
    final key = (notebookId: widget.notebookId, pageId: page.id);
    _ensureLoaded(key);

    return Scaffold(
      appBar: AppBar(
        title: Text(_notebook?.title ?? 'Notebook'),
        actions: [
          IconButton(
            tooltip: 'Book view',
            icon: const Icon(Icons.menu_book_outlined),
            onPressed: () =>
                context.push('/note2/${widget.notebookId}/book'),
          ),
          Center(child: Text('${(zoom * 100).round()}%')),
          IconButton(
            tooltip: 'Reset view',
            icon: const Icon(Icons.center_focus_strong),
            onPressed: () => ref.read(viewportProvider.notifier).reset(),
          ),
          EditorAppBarActions(pageKey: key),
        ],
      ),
      body: SceneCanvas(
        key: ValueKey(page.id),
        notebookId: widget.notebookId,
        pageId: page.id,
        backgroundColor: _paperColor,
        templateType: _template,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _PageNavBar(
            index: index,
            count: pageState.pages.length,
            onPrev: index > 0
                ? () => _switchTo(index - 1)
                : null,
            onNext: index < pageState.pages.length - 1
                ? () => _switchTo(index + 1)
                : null,
            onAdd: () =>
                ref.read(pageProvider(widget.notebookId).notifier).insertPage(),
          ),
          EditorBottomBar(pageKey: key),
        ],
      ),
    );
  }

  void _switchTo(int i) {
    ref.read(selectionProvider.notifier).clear();
    ref.read(pageProvider(widget.notebookId).notifier).switchPage(i);
  }
}

class _PageNavBar extends StatelessWidget {
  final int index;
  final int count;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onAdd;

  const _PageNavBar({
    required this.index,
    required this.count,
    required this.onPrev,
    required this.onNext,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Previous page',
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
            ),
            Text('Page ${index + 1} / $count'),
            IconButton(
              tooltip: 'Next page',
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Add page',
              icon: const Icon(Icons.add),
              onPressed: onAdd,
            ),
          ],
        ),
      ),
    );
  }
}
