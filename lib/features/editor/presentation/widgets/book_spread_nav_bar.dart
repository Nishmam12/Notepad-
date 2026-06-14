import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_colors.dart';
import '../book_view_notifier.dart';
import '../page_notifier.dart';
import '../../data/storage/thumbnail_cache_manager.dart';

class BookSpreadNavBar extends ConsumerStatefulWidget {
  final int notebookId;
  const BookSpreadNavBar({super.key, required this.notebookId});

  @override
  ConsumerState<BookSpreadNavBar> createState() => _BookSpreadNavBarState();
}

class _BookSpreadNavBarState extends ConsumerState<BookSpreadNavBar> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSpread(int spreadIndex) {
    const itemWidth = 80.0 + 8.0; // thumbnail width + margin
    final targetOffset = spreadIndex * itemWidth;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Note: ConsumerState already has ref available
    final bookViewState = ref.watch(bookViewProvider(widget.notebookId));
    final pageState = ref.watch(pageProvider(widget.notebookId));
    final totalPages = pageState.pages.length;
    // Book layout: cover sits alone on spread 0, so there are (totalPages ~/ 2)
    // + 1 spreads (spread indices 0 .. totalPages ~/ 2).
    final totalSpreads = totalPages == 0 ? 0 : (totalPages ~/ 2) + 1;

    // Auto-scroll when spread changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSpread(bookViewState.currentSpread);
    });

    return Container(
      height: 90,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          // Left arrow
          IconButton(
            icon: Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: bookViewState.currentSpread > 0
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
            onPressed: bookViewState.currentSpread > 0
                ? () => ref.read(bookViewProvider(widget.notebookId).notifier).previousSpread()
                : null,
          ),

          // Thumbnail filmstrip
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: totalSpreads,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemBuilder: (context, spreadIndex) {
                final leftPageIndex = spreadIndex * 2 - 1;
                final rightPageIndex = spreadIndex * 2;
                final isActive = spreadIndex == bookViewState.currentSpread;
                // Jump to a page that actually belongs to this spread (the right
                // page, falling back to the last valid page on a partial spread).
                final tapTarget =
                    rightPageIndex < totalPages ? rightPageIndex : totalPages - 1;

                return GestureDetector(
                  onTap: () => ref
                      .read(bookViewProvider(widget.notebookId).notifier)
                      .jumpToPage(tapTarget),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isActive ? AppColors.accent : AppColors.border,
                        width: isActive ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: isActive ? AppColors.shadowCard : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Row(
                        children: [
                          // Left page thumbnail
                          Expanded(
                            child: _SpreadThumbnailHalf(
                              notebookId: widget.notebookId,
                              pageIndex: leftPageIndex,
                              totalPages: totalPages,
                            ),
                          ),
                          // Mini spine
                          Container(
                            width: 2,
                            color: AppColors.border,
                          ),
                          // Right page thumbnail
                          Expanded(
                            child: _SpreadThumbnailHalf(
                              notebookId: widget.notebookId,
                              pageIndex: rightPageIndex,
                              totalPages: totalPages,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Right arrow
          IconButton(
            icon: Icon(
              Icons.arrow_forward_ios,
              size: 18,
              color: bookViewState.currentSpread < totalSpreads - 1
                  ? AppColors.textPrimary
                  : AppColors.textMuted,
            ),
            onPressed: bookViewState.currentSpread < totalSpreads - 1
                ? () => ref.read(bookViewProvider(widget.notebookId).notifier).nextSpread()
                : null,
          ),
        ],
      ),
    );
  }
}

// Helper widget for one half of a spread thumbnail
class _SpreadThumbnailHalf extends StatelessWidget {
  final int notebookId;
  final int pageIndex;
  final int totalPages;

  const _SpreadThumbnailHalf({
    required this.notebookId,
    required this.pageIndex,
    required this.totalPages,
  });

  @override
  Widget build(BuildContext context) {
    if (pageIndex < 0 || pageIndex >= totalPages) {
      // Empty page slot (e.g. the blank left of the cover) — show blank.
      return Container(color: AppColors.surfaceHighlight);
    }
    return FutureBuilder<ui.Image?>(
      future: ThumbnailCacheManager.getThumbnail(notebookId, pageIndex),
      builder: (context, snapshot) {
        if (snapshot.data != null) {
          return RawImage(
            image: snapshot.data,
            fit: BoxFit.cover,
          );
        }
        // Thumbnail not yet generated — show warm placeholder
        return Container(
          color: AppColors.paperCream,
          child: const Center(
            child: Icon(Icons.article_outlined, size: 14, color: AppColors.textMuted),
          ),
        );
      },
    );
  }
}
