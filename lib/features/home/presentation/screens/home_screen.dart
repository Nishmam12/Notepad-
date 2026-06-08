// Home screen displaying a grid of notebooks with create and delete actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../home_notifier.dart';
import '../../domain/models/notebook.dart';
import 'dart:math';
import '../../../editor/domain/models/stroke.dart';
import '../../../editor/domain/models/stroke_point.dart';
import '../../../editor/data/storage/ink_file_storage.dart';
import '../../../editor/presentation/page_notifier.dart';
import '../../data/repositories/page_repository.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notebooks = ref.watch(homeNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'InkFlow',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Generate Large Document (Test)',
            onPressed: () => _generateMockData(context, ref),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: notebooks.isEmpty
          ? _buildEmptyState(context)
          : _buildNotebookGrid(context, ref, notebooks),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _createNotebook(context, ref),
        tooltip: 'Create Notebook',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.note_add_outlined,
            size: 72,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          Text(
            'No notebooks yet',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first notebook',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotebookGrid(
    BuildContext context,
    WidgetRef ref,
    List<Notebook> notebooks,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.85,
        ),
        itemCount: notebooks.length,
        itemBuilder: (context, index) {
          final notebook = notebooks[index];
          return _NotebookCard(
            notebook: notebook,
            onTap: () => context.push('/note/${notebook.id}'),
            onLongPress: () => _confirmDelete(context, ref, notebook),
          );
        },
      ),
    );
  }

  Future<void> _createNotebook(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();

    try {
      final title = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('New Notebook'),
          content: TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Notebook title',
              hintStyle: TextStyle(color: AppColors.textMuted),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Create'),
            ),
          ],
        ),
      );

      if (title != null && title.trim().isNotEmpty) {
        await ref.read(homeNotifierProvider.notifier).createNotebook(title.trim());
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _generateMockData(BuildContext context, WidgetRef ref) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text("Generating 100 pages..."),
          ],
        ),
      ),
    );

    try {
      final title = 'Perf Test ${DateTime.now().millisecondsSinceEpoch}';
      final notebook = await ref.read(homeNotifierProvider.notifier).createNotebook(title);

      final random = Random();
      for (int i = 0; i < 100; i++) {
        final strokes = <Stroke>[];
        for (int s = 0; s < 50; s++) { // 50 strokes per page
          final points = <StrokePoint>[];
          for (int p = 0; p < 20; p++) {
            points.add(StrokePoint(
              x: random.nextDouble() * 500,
              y: random.nextDouble() * 800,
              pressure: random.nextDouble(),
            ));
          }
          strokes.add(Stroke(
            id: 'mock_${i}_$s',
            color: 0xFF000000,
            size: 5.0,
            opacity: 1.0,
            isEraser: false,
            points: points,
          ));
        }
        
        await InkFileStorage.saveStrokes(
          notebookId: notebook.id,
          pageId: i,
          strokes: strokes,
        );
        
        if (i > 0) { // first page is created with notebook automatically
          await ref.read(pageRepositoryProvider).createPage(notebook.id);
        }
      }
    } finally {
      if (context.mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Notebook notebook,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Notebook'),
        content: Text(
          'Delete "${notebook.title}"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.accentRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(homeNotifierProvider.notifier).deleteNotebook(notebook.id);
    }
  }
}

class _NotebookCard extends StatelessWidget {
  final Notebook notebook;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NotebookCard({
    required this.notebook,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notebook icon area
              Expanded(
                child: Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    size: 48,
                    color: AppColors.accent.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              // Title
              Text(
                notebook.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              // Page count and modified date
              Text(
                '${notebook.pageCount} ${notebook.pageCount == 1 ? 'page' : 'pages'}',
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
