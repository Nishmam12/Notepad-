import '../../domain/models/shape_element.dart';
import '../../presentation/shape_notifier.dart';
import 'command.dart';

class ShapeAddCommand extends Command {
  final ShapeNotifier _shapeNotifier;
  final ShapeElement _shape;

  ShapeAddCommand({
    required ShapeNotifier shapeNotifier,
    required ShapeElement shape,
  })  : _shapeNotifier = shapeNotifier,
        _shape = shape;

  @override
  void execute() {
    _shapeNotifier.addShape(_shape);
  }

  @override
  void undo() {
    _shapeNotifier.removeShape(_shape.id);
  }
}
