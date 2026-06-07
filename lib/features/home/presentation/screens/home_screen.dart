// Home screen displaying a grid of notebooks with create and delete actions.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../home_notifier.dart';
import '../../domain/models/notebook.dart';

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
