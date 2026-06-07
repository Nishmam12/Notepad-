import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/features/editor/data/storage/page_cache_manager.dart';

void main() {
  group('PageCacheManager LRU Eviction', () {
    late PageCacheManager cacheManager;

    setUp(() {
      cacheManager = PageCacheManager();
    });

    test('evictStale removes pages outside of currentIndex ± 1', () {
      // Manually populate cache to simulate memory state
      cacheManager.cache[0] = PageData(0, [], null);
      cacheManager.cache[1] = PageData(1, [], null);
      cacheManager.cache[2] = PageData(2, [], null);
      cacheManager.cache[3] = PageData(3, [], null);
      cacheManager.cache[4] = PageData(4, [], null);

      // User jumps to page 2 (indexes 1, 2, 3 should remain)
      cacheManager.evictStale(2);

      expect(cacheManager.cache.containsKey(0), isFalse, reason: 'Index 0 should be evicted');
      expect(cacheManager.cache.containsKey(1), isTrue, reason: 'Index 1 should remain (current - 1)');
      expect(cacheManager.cache.containsKey(2), isTrue, reason: 'Index 2 should remain (current)');
      expect(cacheManager.cache.containsKey(3), isTrue, reason: 'Index 3 should remain (current + 1)');
      expect(cacheManager.cache.containsKey(4), isFalse, reason: 'Index 4 should be evicted');
      expect(cacheManager.cache.length, 3);
    });

    test('evictStale handles edge case at page 0', () {
      cacheManager.cache[0] = PageData(0, [], null);
      cacheManager.cache[1] = PageData(1, [], null);
      cacheManager.cache[2] = PageData(2, [], null);

      cacheManager.evictStale(0);

      expect(cacheManager.cache.containsKey(0), isTrue);
      expect(cacheManager.cache.containsKey(1), isTrue);
      expect(cacheManager.cache.containsKey(2), isFalse);
      expect(cacheManager.cache.length, 2); // Only 0 and 1
    });

    test('clear empties the entire cache', () {
      cacheManager.cache[0] = PageData(0, [], null);
      cacheManager.cache[1] = PageData(1, [], null);
      
      cacheManager.clear();
      
      expect(cacheManager.cache.isEmpty, isTrue);
    });
  });
}
