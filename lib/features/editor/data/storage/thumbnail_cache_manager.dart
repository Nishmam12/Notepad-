import 'dart:ui' as ui;
import 'page_thumbnail_service.dart';

class ThumbnailCacheManager {
  static const int _maxCapacity = 30; // Enough for the visible filmstrip
  static final Map<String, ui.Image> _cache = {};
  static final List<String> _lruKeys = [];

  static Future<ui.Image?> getThumbnail(int notebookId, int pageIndex) async {
    final key = '${notebookId}_$pageIndex';

    if (_cache.containsKey(key)) {
      _lruKeys.remove(key);
      _lruKeys.add(key);
      return _cache[key];
    }

    // Cache miss, load from disk
    final image = await PageThumbnailService.getThumbnailLazy(notebookId, pageIndex);
    if (image == null) return null;

    if (_cache.length >= _maxCapacity) {
      final oldestKey = _lruKeys.removeAt(0);
      final oldestImage = _cache.remove(oldestKey);
      // Wait, can we dispose it? 
      // If PageCacheManager also holds a reference to the SAME image, disposing it will crash the canvas!
      // But PageThumbnailService.getThumbnailLazy creates a NEW ui.Image instance every time it reads from disk!
      // So yes, we can safely dispose this specific instance.
      oldestImage?.dispose();
    }

    _cache[key] = image;
    _lruKeys.add(key);

    return image;
  }

  static void invalidate(int notebookId, int pageIndex) {
    final key = '${notebookId}_$pageIndex';
    _cache.remove(key);
    _lruKeys.remove(key);
    // Note: We do not call image?.dispose() here because the filmstrip UI
    // is likely still rendering this thumbnail while the new one is generating.
  }

  static void clear() {
    for (final image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    _lruKeys.clear();
  }
}
