import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'page_notifier.dart';

class BookViewState {
  final int currentSpread;
  final int totalPages;

  const BookViewState({
    required this.currentSpread,
    required this.totalPages,
  });
}

class BookViewNotifier extends StateNotifier<BookViewState> {
  BookViewNotifier({required int totalPages, int initialSpread = 0})
      : super(BookViewState(currentSpread: initialSpread, totalPages: totalPages));

  void updateTotalPages(int totalPages) {
    state = BookViewState(
      currentSpread: state.currentSpread,
      totalPages: totalPages,
    );
  }

  /// Returns the zero-indexed page indices for the current spread.
  /// Index -1 represents an empty slot (e.g., the left side of the cover page).
  List<int> get pagesForSpread => calculateSpreadPages(state.currentSpread);

  List<int> calculateSpreadPages(int spreadIndex) {
    final left = spreadIndex * 2;
    final right = spreadIndex * 2 + 1;
    return [left, right];
  }

  void nextSpread() {
    final maxSpread = (state.totalPages - 1) ~/ 2;
    if (state.currentSpread < maxSpread) {
      state = BookViewState(
        currentSpread: state.currentSpread + 1,
        totalPages: state.totalPages,
      );
    }
  }

  void previousSpread() {
    if (state.currentSpread > 0) {
      state = BookViewState(
        currentSpread: state.currentSpread - 1,
        totalPages: state.totalPages,
      );
    }
  }
  
  /// Jumps to the spread that contains the given pageIndex
  void jumpToPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= state.totalPages) return;
    
    final targetSpread = pageIndex ~/ 2;
    if (targetSpread != state.currentSpread) {
      state = BookViewState(
        currentSpread: targetSpread,
        totalPages: state.totalPages,
      );
    }
  }
}

final bookViewProvider = StateNotifierProvider.family<BookViewNotifier, BookViewState, int>((ref, notebookId) {
  final initialPages = ref.read(pageProvider(notebookId)).pages.length;
  final notifier = BookViewNotifier(totalPages: initialPages);
  
  ref.listen(pageProvider(notebookId), (previous, next) {
    notifier.updateTotalPages(next.pages.length);
  });
  
  return notifier;
});

