import '../../domain/models/stroke.dart';
import '../../domain/models/shape_element.dart';
import '../../presentation/canvas_notifier.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

class LassoDeleteCommand extends Command {
  final CanvasStateNotifier _canvasNotifier;
  final ShapeNotifier _shapeNotifier;
  
  final List<Stroke> _deletedStrokes;
  final List<ShapeElement> _deletedShapes;

  LassoDeleteCommand({
    required CanvasStateNotifier canvasNotifier,
    required ShapeNotifier shapeNotifier,
    required List<Stroke> deletedStrokes,
    required List<ShapeElement> deletedShapes,
  })  : _canvasNotifier = canvasNotifier,
        _shapeNotifier = shapeNotifier,
        _deletedStrokes = deletedStrokes,
        _deletedShapes = deletedShapes;

  @override
  void execute() {
    for (final stroke in _deletedStrokes) {
      _canvasNotifier.removeStroke(stroke.id);
    }
    for (final shape in _deletedShapes) {
      _shapeNotifier.removeShape(shape.id);
    }
  }

  @override
  void undo() {
    for (final stroke in _deletedStrokes) {
      _canvasNotifier.addStroke(stroke);
    }
    for (final shape in _deletedShapes) {
      _shapeNotifier.addShape(shape);
    }
  }
}
