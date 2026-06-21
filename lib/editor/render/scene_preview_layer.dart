// Draws the single live preview element during shape creation (scene coords).

import 'package:flutter/material.dart';

import '../../domain/model/scene_element.dart';
import 'scene_element_painter.dart';

class ScenePreviewLayer extends CustomPainter {
  final SceneElement? element;

  const ScenePreviewLayer(this.element);

  @override
  void paint(Canvas canvas, Size size) {
    final e = element;
    if (e != null) SceneElementPainter.paint(canvas, e);
  }

  @override
  bool shouldRepaint(ScenePreviewLayer oldDelegate) =>
      !identical(element, oldDelegate.element);
}
