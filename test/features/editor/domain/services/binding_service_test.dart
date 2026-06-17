import 'package:flutter_test/flutter_test.dart';

import 'package:inkflow/features/editor/domain/models/shape_element.dart';
import 'package:inkflow/features/editor/domain/models/shape_type.dart';
import 'package:inkflow/features/editor/domain/services/binding_service.dart';

ShapeElement _base(String id, ShapeType type, List<double> geom) => ShapeElement()
  ..id = id
  ..type = type
  ..color = 0xFF000000
  ..strokeWidth = 2
  ..hasFill = false
  ..fillColor = 0
  ..opacity = 1.0
  ..rotation = 0.0
  ..text = ''
  ..fontSize = 16
  ..fontFamily = 'Roboto'
  ..isBold = false
  ..isItalic = false
  ..svgRelativePath = ''
  ..zOrder = 0
  ..geometryData = geom;

void main() {
  group('BindingService', () {
    test('bindNewArrow binds an endpoint dropped over a shape and snaps it', () {
      final rect = _base('r1', ShapeType.rectangle, [0, 0, 100, 100]);
      // Arrow from far right, ending just over the rectangle's right edge.
      final arrow =
          _base('a1', ShapeType.arrow, [300, 50, 98, 50, 0, 0, 0, 0]);

      final bound = BindingService.bindNewArrow(arrow, [rect]);

      expect(bound.endBindingId, 'r1');
      expect(bound.startBindingId, '');
      // End re-anchored onto the edge along the ray toward the free start.
      expect(bound.geometryData[2], closeTo(100, 1e-6));
      expect(bound.geometryData[3], closeTo(50, 1e-6));
    });

    test('rerouteArrows re-anchors a bound endpoint when its shape moves', () {
      final movedRect = _base('r1', ShapeType.rectangle, [0, 100, 100, 200]);
      final arrow = _base('a1', ShapeType.arrow, [300, 50, 200, 50, 0, 0, 0, 0])
        ..endBindingId = 'r1';

      final out = BindingService.rerouteArrows(
        arrowsToCheck: [arrow],
        currentShapes: [movedRect, arrow],
        changedShapeIds: {'r1'},
      );

      expect(out, hasLength(1));
      // centre (50,150); ray toward free start (300,50): t = 1/max(250/50,100/50)=1/5
      // anchor = (50 + 250/5, 150 - 100/5) = (100, 130)
      expect(out.single.geometryData[2], closeTo(100, 1e-6));
      expect(out.single.geometryData[3], closeTo(130, 1e-6));
      expect(out.single.endBindingId, 'r1'); // binding preserved
    });

    test('rerouteArrows ignores arrows whose shape did not change', () {
      final rect = _base('r1', ShapeType.rectangle, [0, 0, 100, 100]);
      final arrow = _base('a1', ShapeType.arrow, [300, 50, 100, 50, 0, 0, 0, 0])
        ..endBindingId = 'r1';

      final out = BindingService.rerouteArrows(
        arrowsToCheck: [arrow],
        currentShapes: [rect, arrow],
        changedShapeIds: {'someOtherShape'},
      );

      expect(out, isEmpty);
    });
  });
}
