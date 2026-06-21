import 'package:flutter_test/flutter_test.dart';
import 'package:inkflow/domain/model/scene_element.dart';
import 'package:inkflow/editor/state/editor_tool_controller.dart';

void main() {
  test('EditorToolController updates tool/color/size/opacity', () {
    final c = EditorToolController();
    expect(c.state.tool, EditorTool.pen);
    expect(c.state.isHand, false);

    c.setTool(EditorTool.hand);
    expect(c.state.tool, EditorTool.hand);
    expect(c.state.isHand, true);

    c.setColor(0xFFFF0000);
    expect(c.state.color, 0xFFFF0000);

    c.setSize(12);
    expect(c.state.size, 12);

    c.setOpacity(0.4);
    expect(c.state.opacity, 0.4);
  });

  test('setShapeType switches to the shape tool and records the type', () {
    final c = EditorToolController();
    c.setShapeType(ShapeType.diamond);
    expect(c.state.tool, EditorTool.shape);
    expect(c.state.shapeType, ShapeType.diamond);
  });

  test('shape style setters update state', () {
    final c = EditorToolController();
    c.setHasFill(true);
    c.setFillColor(0xFF00FF00);
    c.setFillStyle(FillStyle.solid);
    c.setStrokeStyle(StrokeStyle.dashed);
    c.setEdges(EdgeStyle.round);
    c.setRoughness(2.0);
    c.setEndArrowhead(Arrowhead.dot);
    c.setElbowed(true);

    expect(c.state.hasFill, true);
    expect(c.state.fillColor, 0xFF00FF00);
    expect(c.state.fillStyle, FillStyle.solid);
    expect(c.state.strokeStyle, StrokeStyle.dashed);
    expect(c.state.edges, EdgeStyle.round);
    expect(c.state.roughness, 2.0);
    expect(c.state.endArrowhead, Arrowhead.dot);
    expect(c.state.elbowed, true);
  });
}
