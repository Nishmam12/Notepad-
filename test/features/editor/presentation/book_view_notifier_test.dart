import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/editor/presentation/book_view_notifier.dart';

void main() {
  group('BookViewNotifier', () {
    test('initial state is correct', () {
      final notifier = BookViewNotifier(totalPages: 5);
      expect(notifier.state.currentSpread, 0);
      expect(notifier.state.totalPages, 5);
      expect(notifier.pagesForSpread, [-1, 0]);
    });

    test('nextSpread increments correctly within bounds', () {
      final notifier = BookViewNotifier(totalPages: 4); // Spreads: 0, 1, 2
      
      notifier.nextSpread();
      expect(notifier.state.currentSpread, 1);
      expect(notifier.pagesForSpread, [1, 2]);

      notifier.nextSpread();
      expect(notifier.state.currentSpread, 2);
      expect(notifier.pagesForSpread, [3, 4]);

      // Should not exceed max spread
      notifier.nextSpread();
      expect(notifier.state.currentSpread, 2);
    });

    test('previousSpread decrements correctly within bounds', () {
      final notifier = BookViewNotifier(totalPages: 4, initialSpread: 2);
      
      notifier.previousSpread();
      expect(notifier.state.currentSpread, 1);

      notifier.previousSpread();
      expect(notifier.state.currentSpread, 0);

      // Should not go below 0
      notifier.previousSpread();
      expect(notifier.state.currentSpread, 0);
    });

    test('jumpToPage calculates correct spread', () {
      final notifier = BookViewNotifier(totalPages: 10);
      
      notifier.jumpToPage(0); // Cover
      expect(notifier.state.currentSpread, 0);

      notifier.jumpToPage(1); // Page 1 (left side of spread 1)
      expect(notifier.state.currentSpread, 1);

      notifier.jumpToPage(2); // Page 2 (right side of spread 1)
      expect(notifier.state.currentSpread, 1);

      notifier.jumpToPage(3); // Page 3 (left side of spread 2)
      expect(notifier.state.currentSpread, 2);
    });
    
    test('updateTotalPages updates totalPages without changing spread', () {
      final notifier = BookViewNotifier(totalPages: 3, initialSpread: 1);
      notifier.updateTotalPages(5);
      expect(notifier.state.totalPages, 5);
      expect(notifier.state.currentSpread, 1);
    });
  });
}
