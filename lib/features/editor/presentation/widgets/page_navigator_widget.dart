import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/storage/thumbnail_cache_manager.dart';
import '../page_notifier.dart';

class PageNavigatorWidget extends ConsumerStatefulWidget {
  final int notebookId;
  final Axis direction;

  const PageNavigatorWidget({
    super.key, 
    required this.notebookId,
    this.direction = Axis.horizontal,
  });

  @override
  ConsumerState<PageNavigatorWidget> createState() => _PageNavigatorWidgetState();
}

class _PageNavigatorWidgetState extends ConsumerState<PageNavigatorWidget> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrent(int index) {
    if (!_scrollController.hasClients) return;
    final targetOffset = index * 100.0; // approx width
    if (targetOffset < _scrollController.position.minScrollExtent ||
        targetOffset > _scrollController.position.maxScrollExtent) {
      return;
    }

    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _showPageOptions(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.textPrimary),
                title: const Text('Duplicate', style: TextStyle(color: AppColors.textPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(pageProvider(widget.notebookId).notifier).duplicatePage(index);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.accentRed),
                title: const Text('Delete', style: TextStyle(color: AppColors.accentRed)),
                onTap: () {
                  Navigator.pop(context);
                  ref.read(pageProvider(widget.notebookId).notifier).deletePage(index);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final pageState = ref.watch(pageProvider(widget.notebookId));

    ref.listen(pageProvider(widget.notebookId), (previous, next) {
      if (previous?.currentPageIndex != next.currentPageIndex) {
        _scrollToCurrent(next.currentPageIndex);
      }
    });

    final isVertical = widget.direction == Axis.vertical;

    return Container(
      height: isVertical ? double.infinity : 120,
      width: isVertical ? 120 : double.infinity,
      color: AppColors.surface,
      child: Flex(
        direction: widget.direction,
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: widget.direction,
              itemCount: pageState.pages.length,
              itemBuilder: (context, index) {
                final isActive = index == pageState.currentPageIndex;
                return GestureDetector(
                  onTap: () => ref.read(pageProvider(widget.notebookId).notifier).switchPage(index),
                  onLongPress: () => _showPageOptions(context, index),
                  child: Container(
                    margin: isVertical 
                        ? const EdgeInsets.fromLTRB(16, 16, 16, 0)
                        : const EdgeInsets.fromLTRB(16, 16, 0, 16),
                    width: isVertical ? double.infinity : 72,
                    height: isVertical ? 100 : null,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      border: Border.all(
                        color: isActive ? AppColors.accent : AppColors.border,
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: FutureBuilder<ui.Image?>(
                            future: ThumbnailCacheManager.getThumbnail(widget.notebookId, index),
                            builder: (context, snapshot) {
                              if (snapshot.data == null) {
                                return const Center(
                                  child: Icon(Icons.note, color: AppColors.textMuted),
                                );
                              }
                              return RawImage(
                                image: snapshot.data,
                                fit: BoxFit.contain,
                              );
                            },
                          ),
                        ),
                        Positioned(
                          bottom: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.surface.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${index + 1}',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (!isVertical) const SizedBox(width: 16),
          if (isVertical) const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.only(
              right: isVertical ? 0 : 16,
              bottom: isVertical ? 16 : 0,
            ),
            child: FloatingActionButton(
              heroTag: null,
              backgroundColor: AppColors.surfaceHighlight,
              elevation: 0,
              onPressed: () => ref.read(pageProvider(widget.notebookId).notifier).insertPage(),
              child: const Icon(Icons.add, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
