// Reference-counted cache. Acquired values stay alive while referenced and are
// disposed exactly once when the last reference is released. This is the
// foundation for the crash-free `dart:ui.Image` cache (the "Cannot clone a
// disposed image" fix): the widget tree holds references; an image is only
// disposed when nothing paints it. Real ui.Image wiring lands with image import
// (Phase 7); the bookkeeping is unit-tested here.

class _Entry<T> {
  final T value;
  int count = 0;
  _Entry(this.value);
}

class RefCountedCache<T> {
  final void Function(T value) onDispose;
  final Map<String, _Entry<T>> _entries = {};

  RefCountedCache(this.onDispose);

  /// Returns the cached value for [key], creating it on first use, and adds a
  /// reference. Every [acquire] must be paired with a [release].
  T acquire(String key, T Function() create) {
    final entry = _entries.putIfAbsent(key, () => _Entry(create()));
    entry.count++;
    return entry.value;
  }

  /// Drops a reference; disposes the value when the count reaches zero.
  void release(String key) {
    final entry = _entries[key];
    if (entry == null) return;
    entry.count--;
    if (entry.count <= 0) {
      _entries.remove(key);
      onDispose(entry.value);
    }
  }

  int refCount(String key) => _entries[key]?.count ?? 0;
  bool contains(String key) => _entries.containsKey(key);

  void disposeAll() {
    for (final e in _entries.values) {
      onDispose(e.value);
    }
    _entries.clear();
  }
}
