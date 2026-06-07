import 'dart:async';
import 'dart:ui' as ui;

class PdfCacheManager {
  static const int _maxCapacity = 50;

  final Map<String, ui.Image> _cache = {};
  final List<String> _lruKeys = [];
  
  // Simple lock to ensure thread safety during async operations
  bool _isLocked = false;
  final List<Completer<void>> _waitQueue = [];

  Future<void> _acquireLock() async {
    if (!_isLocked) {
      _isLocked = true;
      return;
    }
    final completer = Completer<void>();
    _waitQueue.add(completer);
    await completer.future;
  }

  void _releaseLock() {
    if (_waitQueue.isNotEmpty) {
      final next = _waitQueue.removeAt(0);
      next.complete();
    } else {
      _isLocked = false;
    }
  }

  Future<ui.Image?> get(String key) async {
    await _acquireLock();
    try {
      if (_cache.containsKey(key)) {
        // Move to back of LRU (most recently used)
        _lruKeys.remove(key);
        _lruKeys.add(key);
        return _cache[key];
      }
      return null;
    } finally {
      _releaseLock();
    }
  }

  Future<void> put(String key, ui.Image image) async {
    await _acquireLock();
    try {
      if (_cache.containsKey(key)) {
        // If it already exists, replace it, dispose old, update LRU
        final oldImage = _cache[key];
        if (oldImage != image) {
          oldImage?.dispose();
        }
        _cache[key] = image;
        _lruKeys.remove(key);
        _lruKeys.add(key);
      } else {
        // Enforce capacity
        if (_cache.length >= _maxCapacity) {
          final oldestKey = _lruKeys.removeAt(0);
          final oldestImage = _cache.remove(oldestKey);
          oldestImage?.dispose();
        }
        
        _cache[key] = image;
        _lruKeys.add(key);
      }
    } finally {
      _releaseLock();
    }
  }

  Future<void> evictAll() async {
    await _acquireLock();
    try {
      for (final image in _cache.values) {
        image.dispose();
      }
      _cache.clear();
      _lruKeys.clear();
    } finally {
      _releaseLock();
    }
  }

  Future<void> dispose() async {
    await evictAll();
  }
}
