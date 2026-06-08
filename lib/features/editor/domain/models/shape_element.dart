// Represents one vector shape, text box, or SVG element on a note page.
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'shape_type.dart';

part 'shape_element.g.dart';

@embedded
class ShapeElement {
  // Identity
  late String id;
  @enumerated
  late ShapeType type;

  // Stroke appearance
  late int color;         // ARGB int (e.g. 0xFF58A6FF)
  late double strokeWidth;
  late bool hasFill;
  late int fillColor;     // ARGB int, used when hasFill == true
  late double opacity;    // 0.0 to 1.0

  // Geometry — interpreted based on type
  // For line/arrow: [startX, startY, endX, endY]
  // For circle: [centerX, centerY, radiusX, radiusY]
  // For rectangle: [left, top, right, bottom]
  // For triangle/polygon: [x0,y0, x1,y1, x2,y2, ...] flat list of vertices
  // For textBox: [left, top, right, bottom] (bounding box)
  // For svgImage: [left, top, right, bottom]
  late List<double> geometryData;

  // Transform
  late double rotation; // radians, clockwise around shape centre

  // Text fields (type == textBox only)
  late String text;
  late double fontSize;
  late String fontFamily; // e.g. 'Roboto'
  late bool isBold;
  late bool isItalic;

  // SVG fields (type == svgImage only)
  late String svgRelativePath; // relative path to cached .svg file

  // Ordering
  late int zOrder;

  ShapeElement();

  factory ShapeElement.line({required String id, required Offset start,
      required Offset end, required int color, required double strokeWidth}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.line ..color = color
      ..strokeWidth = strokeWidth ..hasFill = false ..fillColor = 0
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = [start.dx, start.dy, end.dx, end.dy];
  }

  factory ShapeElement.arrow({required String id, required Offset start,
      required Offset end, required List<double> arrowPoints, required int color, required double strokeWidth}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.arrow ..color = color
      ..strokeWidth = strokeWidth ..hasFill = false ..fillColor = 0
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = [start.dx, start.dy, end.dx, end.dy, ...arrowPoints];
  }

  factory ShapeElement.circle({required String id, required Rect rect, required int color, required double strokeWidth, bool hasFill = false, int fillColor = 0}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.circle ..color = color
      ..strokeWidth = strokeWidth ..hasFill = hasFill ..fillColor = fillColor
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = [rect.left, rect.top, rect.right, rect.bottom];
  }

  factory ShapeElement.rectangle({required String id, required Rect rect, required int color, required double strokeWidth, bool hasFill = false, int fillColor = 0}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.rectangle ..color = color
      ..strokeWidth = strokeWidth ..hasFill = hasFill ..fillColor = fillColor
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = [rect.left, rect.top, rect.right, rect.bottom];
  }

  factory ShapeElement.triangle({required String id, required List<Offset> vertices, required int color, required double strokeWidth, bool hasFill = false, int fillColor = 0}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.triangle ..color = color
      ..strokeWidth = strokeWidth ..hasFill = hasFill ..fillColor = fillColor
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = vertices.expand((v) => [v.dx, v.dy]).toList();
  }

  factory ShapeElement.polygon({required String id, required List<Offset> vertices, required int color, required double strokeWidth, bool hasFill = false, int fillColor = 0}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.polygon ..color = color
      ..strokeWidth = strokeWidth ..hasFill = hasFill ..fillColor = fillColor
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = vertices.expand((v) => [v.dx, v.dy]).toList();
  }

  factory ShapeElement.textBox({required String id, required Rect rect, required int color, required String text, required double fontSize}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.textBox ..color = color
      ..strokeWidth = 0 ..hasFill = false ..fillColor = 0
      ..opacity = 1.0 ..rotation = 0 ..text = text ..fontSize = fontSize
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = '' ..zOrder = 0
      ..geometryData = [rect.left, rect.top, rect.right, rect.bottom];
  }

  factory ShapeElement.svgImage({required String id, required Rect rect, required String svgRelativePath}) {
    return ShapeElement()
      ..id = id ..type = ShapeType.svgImage ..color = 0xFF000000
      ..strokeWidth = 0 ..hasFill = false ..fillColor = 0
      ..opacity = 1.0 ..rotation = 0 ..text = '' ..fontSize = 16
      ..fontFamily = 'Roboto' ..isBold = false ..isItalic = false
      ..svgRelativePath = svgRelativePath ..zOrder = 0
      ..geometryData = [rect.left, rect.top, rect.right, rect.bottom];
  }
}
