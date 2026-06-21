// Pure editing helpers for a selection: duplicate, group/ungroup, lock. They
// return new/updated immutable elements; the caller persists via the controller.

import 'dart:ui';

import '../geometry/element_transformer.dart';
import '../model/scene_element.dart';

class SelectionEditing {
  SelectionEditing._();

  /// Duplicates [selected], offsetting each copy by [offset] and giving each a
  /// fresh id. Elements that shared a group get a new shared group, so the
  /// duplicates stay grouped without merging with the originals.
  static List<SceneElement> duplicate(
    Iterable<SceneElement> selected, {
    required Offset offset,
    required String Function() nextId,
  }) {
    final groupRemap = <String, String>{};
    final copies = <SceneElement>[];
    for (final e in selected) {
      final newGroup = e.groupId.isEmpty
          ? ''
          : groupRemap.putIfAbsent(e.groupId, nextId);
      final copy = withGroup(withId(e, nextId()), newGroup);
      copies.add(SceneTransformer.translate(copy, offset));
    }
    return copies;
  }

  static SceneElement withId(SceneElement e, String id) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(id: id);
      case SceneShapeElement():
        return e.copyWith(id: id);
      case TextElement():
        return e.copyWith(id: id);
      case ImageElement():
        return e.copyWith(id: id);
      case FrameElement():
        return e.copyWith(id: id);
    }
  }

  static SceneElement withGroup(SceneElement e, String groupId) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(groupId: groupId);
      case SceneShapeElement():
        return e.copyWith(groupId: groupId);
      case TextElement():
        return e.copyWith(groupId: groupId);
      case ImageElement():
        return e.copyWith(groupId: groupId);
      case FrameElement():
        return e.copyWith(groupId: groupId);
    }
  }

  static SceneElement withLocked(SceneElement e, bool locked) {
    switch (e) {
      case FreehandElement():
        return e.copyWith(isLocked: locked);
      case SceneShapeElement():
        return e.copyWith(isLocked: locked);
      case TextElement():
        return e.copyWith(isLocked: locked);
      case ImageElement():
        return e.copyWith(isLocked: locked);
      case FrameElement():
        return e.copyWith(isLocked: locked);
    }
  }
}
